# frozen_string_literal: true

require "io/nonblock"

# Runs the external programs that we use on untrusted files (ffmpeg, ffprobe, mkvmerge, exiftool) in a sandbox, with
# time, memory, and output limits, so that a malicious file can't make them run forever, use all the memory, or do
# anything else if it manages to exploit a bug in the program.
#
# The sandbox uses Landlock to limit which files the command can access, and seccomp to limit which system calls it can
# make. Both work without root and without any special support from Docker or Kubernetes.
class ExternalCommand
  class Error < StandardError; end
  class TimeoutError < Error; end
  class OutputLimitError < Error; end
  class SyscallError < Error; end

  TIMEOUT = 1.minute
  MEMORY_LIMIT = 4.gigabytes

  # The most output a command can print before it's killed.
  OUTPUT_LIMIT = 16.megabytes

  # The longest it can take to set up the sandbox and start the command.
  STARTUP_TIMEOUT = 10.seconds

  # The environment variables passed to commands. Commands use jemalloc (see the Dockerfile) to stay under the memory limit.
  ENVIRONMENT = %w[PATH LD_PRELOAD MALLOC_CONF].freeze

  # What every command can do: load shared libraries, and use basic syscalls for memory, files, threads, and signals.
  # This leaves out syscalls for starting processes, opening network sockets, creating namespaces, tracing processes,
  # and other things these programs don't need. Commands are killed if they use any other syscall.
  BASE_PROFILE = {
    # /usr/lib has the dynamic linker, which has to be executable, and the real `env` binary that /usr/bin links to.
    execute: %w[/usr/lib],
    read: %w[/etc/ld.so.cache /etc/ld.so.preload /etc/malloc.conf],
    write: %w[/dev/null],
    # socketpair and recvfrom are only for local sockets, since the syscalls for opening network sockets aren't allowed.
    syscalls: %w[
      @exec @exit @memory @process-info @process-self @signal-self @signals @stdio @threads @time @tty
      poll recvfrom socketpair
    ],
  }.freeze

  # What each program can do on top of the base profile. Programs not listed here only get the base profile.
  PROFILES = {
    "ffmpeg" => {
      execute: %w[/usr/local/bin/ffmpeg],
      read: %w[/usr/local/lib],
      # ffmpeg checks stdin for keypresses with pselect6.
      syscalls: %w[getrusage pselect6],
    },
    "ffprobe" => {
      execute: %w[/usr/local/bin/ffprobe],
      read: %w[/usr/local/lib],
    },
    "mkvmerge" => {
      execute: %w[/usr/bin/mkvmerge],
      read: %w[/usr/share/locale],
      syscalls: %w[uname],
    },
    "exiftool" => {
      execute: %w[/usr/local/bin/exiftool /usr/bin/perl],
      read: %w[/usr/local/share/perl /usr/share/perl /usr/share/perl5 /etc/perl /dev/urandom],
      # Perl calls symlink("", "") to check if symlinks are supported. Landlock stops it from creating any.
      syscalls: %w[symlink],
    },
    # Ruby is used to run bin/vips-worker (see Danbooru::Vips). /usr/local/lib has Ruby's standard library, and libvips
    # and its modules.
    "ruby" => {
      execute: %w[/usr/local/bin/ruby],
      read: %w[/usr/local/lib],
      # Ruby uses epoll and eventfd for its timer thread, and turns off transparent huge pages (PR_SET_THP_DISABLE).
      # GLib calls getpeername on stderr when logging a warning, to check whether stderr is connected to journald.
      syscalls: ["epoll_create1", "epoll_ctl", "epoll_wait", "eventfd2", "getpeername", ["prctl", :allow, [[0, :eq, 41]]]],
    },
  }.freeze

  attr_reader :argv, :program, :profile, :read, :write, :timeout, :memory_limit, :output_limit, :env

  # Run a command and return its output. The command is killed if it runs longer than the timeout or prints more than
  # the output limit.
  #
  # The command isn't run through a shell, and it only gets the variables in ENVIRONMENT, so it can't see secrets like
  # database passwords or API keys.
  #
  # @param command [String] The command to run. Arguments must already be shell-escaped.
  # @param read [Array<String>] The files and directories the command can read, besides the system directories.
  # @param write [Array<String>] The files and directories the command can read and write.
  # @param timeout [Integer] The maximum number of seconds the command can run.
  # @param memory_limit [Integer] The maximum number of bytes of memory the command can use.
  # @param output_limit [Integer] The maximum number of bytes the command can print to stdout and stderr.
  # @param env [Hash<String, String>] Extra environment variables to pass to the command.
  # @return [Array<(String, Process::Status)>] The combined stdout and stderr of the command, and its exit status.
  # @raise [TimeoutError] If the command ran longer than the timeout, or setting up the sandbox took longer than STARTUP_TIMEOUT.
  # @raise [OutputLimitError] If the command printed more than the output limit.
  # @raise [SyscallError] If the command was killed for using a blocked system call.
  # @raise [Error] If the sandbox couldn't be set up, or if Landlock isn't supported and the file sandbox isn't disabled.
  def self.run(...)
    new(...).run
  end

  # @see ExternalCommand.run
  def initialize(command, read: [], write: [], timeout: TIMEOUT, memory_limit: MEMORY_LIMIT, output_limit: OUTPUT_LIMIT, env: {}) # rubocop:disable Metrics/ParameterLists
    @argv = command.shellsplit
    @program = argv.first
    raise ArgumentError, "can't run an empty command" if program.nil?

    # Programs are looked up by name, so a program run by its full path gets the same profile. Landlock only lets it run
    # the program in the profile.
    @profile = PROFILES.fetch(File.basename(program), {})
    @read = read
    @write = write
    @timeout = timeout
    @memory_limit = memory_limit
    @output_limit = output_limit
    @env = env
  end

  # @see ExternalCommand.run
  def run
    file_sandbox = file_sandbox?
    deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + timeout
    output, output_writer = IO.pipe
    started, started_writer = IO.pipe
    pid = exited = status = nil

    begin
      # Errors raised in this thread from outside, like Rack::Timeout's, are held off until we have the pid and the
      # status, so we always know whether the command is still running and needs to be killed.
      Thread.handle_interrupt(Object => :never) do
        pid = Process.fork { exec_sandboxed!(output_writer, started_writer, file_sandbox:) }
      end

      output_writer.close
      started_writer.close
      exited = IO.for_fd(LibC.pidfd_open!(pid))

      wait_until_started!(started)
      result = read_output!(output, deadline)

      # The command may have closed its output but kept running. The pidfd is readable once the command exits.
      timed_out! unless exited.wait_readable(remaining(deadline))
      Thread.handle_interrupt(Object => :never) { status = Process.wait2(pid).last }
    ensure
      Thread.handle_interrupt(Object => :never) do
        # Kill the command if we stopped before it exited, because of a timeout, the output limit, or an error from
        # outside. The command can't start other processes, so this stops everything it started. Its pid can't have
        # been reused yet, because we haven't waited on it.
        if pid && status.nil?
          Process.kill(:KILL, pid)
          Process.wait(pid)
        end

        [output, output_writer, started, started_writer, exited].compact.each(&:close)
      end
    end

    raise SyscallError, "#{program} called a blocked syscall" if Seccomp.killed?(status)

    [result.force_encoding(Encoding.default_external), status]
  end

  private

  # @return [Boolean] True if the command should be run with Landlock.
  # @raise [Error] If Landlock isn't supported. Running without it must be explicitly allowed, so that a kernel without
  #   Landlock doesn't silently turn it off.
  def file_sandbox?
    return false if Danbooru.config.disable_file_sandbox?.to_s.truthy?
    raise Error, "can't run #{program}: Landlock isn't supported by this kernel (set DANBOORU_DISABLE_FILE_SANDBOX=true to disable sandboxing)" unless Landlock.supported?

    true
  end

  # Runs in the child. Apply the sandbox and replace the child with the command. If anything fails, send the error to
  # the parent through `started`.
  #
  # This calls execvpe(3) directly instead of `Process.exec`, because when `Process.exec` fails, Ruby restarts its own
  # background threads, which would be killed for using syscalls the sandbox doesn't allow.
  def exec_sandboxed!(output, started, file_sandbox:)
    # Ruby makes pipes non-blocking, which would make the command's writes fail when the pipe is full, so it would lose output.
    output.nonblock = false
    File.open(File::NULL) { LibC.dup2!(it.fileno, 0) }
    LibC.dup2!(output.fileno, 1)
    LibC.dup2!(output.fileno, 2)

    # Close all other files on exec, so the command can't use files or sockets that the Rails process left open.
    LibC.close_range_cloexec!(3)

    c_argv = LibC.string_array(argv)
    c_env = LibC.string_array(ENV.slice(*ENVIRONMENT).merge(env).map { |name, value| "#{name}=#{value}" })

    # Built here, after forking, so that rules for the process itself apply to the command, which keeps this pid.
    seccomp = Seccomp.allow(BASE_PROFILE[:syscalls] + profile.fetch(:syscalls, []))

    if file_sandbox
      Landlock.restrict!(
        read: BASE_PROFILE[:read] + profile.fetch(:read, []) + read,
        execute: BASE_PROFILE[:execute] + profile.fetch(:execute, []),
        write: BASE_PROFILE[:write] + write,
      )
    end

    seccomp.apply!

    # Set the memory limit last, because the child is still a copy of the Rails process until it execs the command, so
    # it would fail to allocate memory. Disable core dumps, otherwise a command that crashes when it hits the memory
    # limit can fill the disk.
    Process.setrlimit(:AS, memory_limit.to_i)
    Process.setrlimit(:CORE, 0)

    LibC.execvpe(program, c_argv, c_env)
    raise SystemCallError.new(nil, FFI.errno)
  rescue Exception => e # rubocop:disable Lint/RescueException
    started.write(e.message) rescue nil # rubocop:disable Style/RescueModifier
  ensure
    # Always exit here, even if reporting the error failed. `exit` would run the parent's at_exit handlers in the child.
    exit!(127) # rubocop:disable Rails/Exit
  end

  # Wait for the child to exec the command. The child runs Ruby code before exec, which can hang forever if another
  # thread held a lock when we forked, so give up after STARTUP_TIMEOUT.
  #
  # @raise [TimeoutError] If the child didn't exec in time.
  # @raise [Error] If setting up the sandbox failed.
  def wait_until_started!(started)
    raise TimeoutError, "#{program} took more than #{STARTUP_TIMEOUT.to_i} seconds to start" if started.wait_readable(STARTUP_TIMEOUT).nil?

    error = started.read
    raise Error, "can't run #{program}: #{error}" if error.present?
  end

  # Read the command's output until it closes it.
  #
  # @return [String] The output, as binary.
  # @raise [TimeoutError] If the command runs past the deadline.
  # @raise [OutputLimitError] If the command prints too much.
  def read_output!(output, deadline)
    buffer = String.new

    loop do
      timed_out! unless output.wait_readable(remaining(deadline))

      chunk = output.read_nonblock(64.kilobytes, exception: false)
      return buffer if chunk.nil?
      next if chunk == :wait_readable

      buffer << chunk
      raise OutputLimitError, "#{program} printed more than #{output_limit} bytes" if buffer.bytesize > output_limit
    end
  end

  # @raise [TimeoutError]
  def timed_out!
    raise TimeoutError, "#{program} timed out after #{timeout.to_i} seconds"
  end

  # @return [Float] The number of seconds left until the deadline, or 0 if it has passed.
  def remaining(deadline)
    [deadline - Process.clock_gettime(Process::CLOCK_MONOTONIC), 0].max
  end

  module LibC
    extend FFI::Library

    ffi_lib FFI::Library::LIBC

    # The syscall numbers are the same on all architectures.
    SYS_PIDFD_OPEN = 434
    SYS_CLOSE_RANGE = 436
    CLOSE_RANGE_CLOEXEC = 1 << 2

    attach_function :syscall, [:long, :varargs], :long
    attach_function :dup2, [:int, :int], :int
    attach_function :execvpe, [:string, :pointer, :pointer], :int

    # @return [Integer] A file descriptor that becomes readable when the process exits.
    def self.pidfd_open!(pid)
      check!(:pidfd_open, syscall(SYS_PIDFD_OPEN, :int, pid, :uint, 0))
    end

    # Set the close-on-exec flag on every file descriptor from `first` up.
    def self.close_range_cloexec!(first)
      check!(:close_range, syscall(SYS_CLOSE_RANGE, :uint, first, :uint, 0xFFFFFFFF, :uint, CLOSE_RANGE_CLOEXEC))
    end

    def self.dup2!(old_fd, new_fd)
      check!(:dup2, dup2(old_fd, new_fd))
    end

    # @return [FFI::MemoryPointer] A NULL-terminated array of C strings.
    def self.string_array(strings)
      pointers = strings.map { FFI::MemoryPointer.from_string(it) } + [nil]
      FFI::MemoryPointer.new(:pointer, pointers.size).put_array_of_pointer(0, pointers)
    end

    def self.check!(name, ret)
      raise SystemCallError.new(name.to_s, FFI.errno) if ret < 0
      ret
    end
  end
end
