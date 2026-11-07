# frozen_string_literal: true

# A wrapper around Landlock, a Linux kernel feature that lets an unprivileged process restrict which files it can access
# and which network ports it can use. The restrictions apply to the process and all of its children, and they can't be
# undone. This is used for sandboxing external programs that process user-uploaded files.
#
# Landlock is available since Linux 5.13, but it must be enabled by the kernel, so it may not be available everywhere.
# Newer kernels support more restrictions (see `Landlock.abi_version`).
#
# @example
#   # Only allow reading /usr and writing /tmp/out for the rest of the program.
#   Landlock.restrict!(read: ["/usr"], write: ["/tmp/out"])
#
# @see https://docs.kernel.org/userspace-api/landlock.html
# @see https://man7.org/linux/man-pages/man7/landlock.7.html
# @see https://github.com/torvalds/linux/blob/master/include/uapi/linux/landlock.h
module Landlock
  class Error < StandardError; end

  # Filesystem access rights, and the ABI version that added them.
  ACCESS_FS = {
    execute:     [1 << 0, 1],
    write_file:  [1 << 1, 1],
    read_file:   [1 << 2, 1],
    read_dir:    [1 << 3, 1],
    remove_dir:  [1 << 4, 1],
    remove_file: [1 << 5, 1],
    make_char:   [1 << 6, 1],
    make_dir:    [1 << 7, 1],
    make_reg:    [1 << 8, 1],
    make_sock:   [1 << 9, 1],
    make_fifo:   [1 << 10, 1],
    make_block:  [1 << 11, 1],
    make_sym:    [1 << 12, 1],
    refer:       [1 << 13, 2],
    truncate:    [1 << 14, 3],
    ioctl_dev:   [1 << 15, 5],
  }

  # The access rights that apply to files. The other rights only apply to directories.
  FILE_ACCESS = %i[execute write_file read_file truncate ioctl_dev]

  # The rights granted to paths that can be read.
  READ_ACCESS = %i[read_file read_dir]

  # The rights granted to paths that can be read and executed.
  EXECUTE_ACCESS = READ_ACCESS + %i[execute]

  # The rights granted to paths that can be written. Written files can't be executed.
  WRITE_ACCESS = READ_ACCESS + %i[write_file remove_dir remove_file make_dir make_reg make_sym truncate]

  # Network access rights (ABI 4+). These block all TCP connections and listening sockets.
  ACCESS_NET = { bind_tcp: 1 << 0, connect_tcp: 1 << 1 }

  # Scopes (ABI 6+). These block connecting to abstract Unix sockets and sending signals outside the sandbox.
  SCOPES = { abstract_unix_socket: 1 << 0, signal: 1 << 1 }

  module LibC
    extend FFI::Library

    ffi_lib FFI::Library::LIBC

    # The syscall numbers are the same on all architectures.
    SYS_LANDLOCK_CREATE_RULESET = 444
    SYS_LANDLOCK_ADD_RULE = 445
    SYS_LANDLOCK_RESTRICT_SELF = 446

    LANDLOCK_CREATE_RULESET_VERSION = 1 << 0
    LANDLOCK_RULE_PATH_BENEATH = 1
    PR_SET_NO_NEW_PRIVS = 38
    O_PATH = 0o10000000 # The same on x86_64 and aarch64.

    attach_function :syscall, [:long, :varargs], :long
    attach_function :prctl, [:int, :ulong, :ulong, :ulong, :ulong], :int
  end

  # struct landlock_ruleset_attr
  class RulesetAttr < FFI::Struct
    layout :handled_access_fs, :uint64, :handled_access_net, :uint64, :scoped, :uint64
  end

  # struct landlock_path_beneath_attr (packed)
  class PathBeneathAttr < FFI::Struct
    pack 1
    layout :allowed_access, :uint64, :parent_fd, :int32
  end

  # @return [Integer] The Landlock ABI version supported by the kernel, or 0 if Landlock isn't available.
  def self.abi_version
    @abi_version ||= [LibC.syscall(LibC::SYS_LANDLOCK_CREATE_RULESET, :pointer, nil, :size_t, 0, :uint32, LibC::LANDLOCK_CREATE_RULESET_VERSION), 0].max
  end

  # Restrict the current process so it can only read the `read` paths, read and run the `execute` paths, and read or
  # write the `write` paths, and so it can't use TCP, connect to abstract Unix sockets, or send signals to processes
  # outside the sandbox. Restrictions that the kernel doesn't support are skipped.
  #
  # @param read [Array<String>] The files and directories that can be read.
  # @param execute [Array<String>] The files and directories that can be read and executed.
  # @param write [Array<String>] The files and directories that can be read and written.
  # @raise [Error] If Landlock isn't available.
  def self.restrict!(read: [], execute: [], write: [])
    raise Error, "Landlock is not supported by this kernel" unless supported?

    ruleset_attr = RulesetAttr.new
    ruleset_attr[:handled_access_fs] = access_mask(ACCESS_FS.keys)
    ruleset_attr[:handled_access_net] = (abi_version >= 4) ? ACCESS_NET.values.sum : 0
    ruleset_attr[:scoped] = (abi_version >= 6) ? SCOPES.values.sum : 0

    # Older kernels reject the fields they don't know about, so only pass the size they support.
    case abi_version
    in 6.. then size = 24
    in 4.. then size = 16
    else size = 8
    end

    ruleset_fd = check!(:landlock_create_ruleset, LibC.syscall(LibC::SYS_LANDLOCK_CREATE_RULESET, :pointer, ruleset_attr, :size_t, size, :uint32, 0))

    read.each { add_path_rule!(ruleset_fd, it, READ_ACCESS) }
    execute.each { add_path_rule!(ruleset_fd, it, EXECUTE_ACCESS) }
    write.each { add_path_rule!(ruleset_fd, it, WRITE_ACCESS) }

    check!(:prctl, LibC.prctl(LibC::PR_SET_NO_NEW_PRIVS, 1, 0, 0, 0))
    check!(:landlock_restrict_self, LibC.syscall(LibC::SYS_LANDLOCK_RESTRICT_SELF, :int, ruleset_fd, :uint32, 0))
  ensure
    IO.for_fd(ruleset_fd).close if ruleset_fd
  end

  # @return [Boolean] True if the kernel supports Landlock.
  def self.supported?
    abi_version >= 1
  end

  # Allow the given access to a file or directory and everything inside it. Paths that don't exist are skipped. Paths
  # that are symlinks aren't allowed, because the rule would give access to whatever the symlink points to, which could
  # be a symlink planted by a malicious file. Symlinks in the directories leading to the path are fine.
  def self.add_path_rule!(ruleset_fd, path, access)
    return unless File.exist?(path)
    raise Error, "#{path} can't be sandboxed because it's a symlink" if File.symlink?(path)

    access &= FILE_ACCESS unless File.directory?(path)

    File.open(path, LibC::O_PATH) do |file|
      rule = PathBeneathAttr.new
      rule[:allowed_access] = access_mask(access)
      rule[:parent_fd] = file.fileno
      check!(:landlock_add_rule, LibC.syscall(LibC::SYS_LANDLOCK_ADD_RULE, :int, ruleset_fd, :int, LibC::LANDLOCK_RULE_PATH_BENEATH, :pointer, rule, :uint32, 0))
    end
  end

  # @return [Integer] The bitmask for the given access rights, minus the rights the kernel doesn't support.
  def self.access_mask(access)
    access.map { ACCESS_FS.fetch(it) }.select { |_bit, abi| abi <= abi_version }.sum(&:first)
  end

  def self.check!(name, ret)
    raise SystemCallError.new(name.to_s, FFI.errno) if ret < 0
    ret
  end

  private_class_method :add_path_rule!, :access_mask, :check!
end
