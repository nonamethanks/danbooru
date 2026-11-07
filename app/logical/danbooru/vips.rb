# frozen_string_literal: true

# Runs libvips on untrusted images in a sandbox, by running bin/vips-worker with ExternalCommand. Each call runs one
# command for all the given files, so callers should pass every file they need at once.
#
# @see https://www.libvips.org/API/current/
class Danbooru::Vips
  class Error < StandardError; end

  # The script that runs libvips.
  WORKER = Rails.root.join("bin/vips-worker").to_s

  # libvips uses liborc, which writes the code it generates to a file in /tmp and then deletes it. Without the file
  # sandbox, the worker is allowed to create the file but would be killed for deleting it, so liborc is turned off. With
  # the sandbox, it can't create the file, so it uses memory instead.
  NO_ORC_ENV = { "ORC_CODE" => "backup", "VIPS_NOVECTOR" => "1" }.freeze

  # The worker runs without RubyGems, so we give it the load paths of the gems it needs.
  LOAD_PATH = %w[ruby-vips ffi logger].map { File.join(Gem.loaded_specs.fetch(it).full_gem_path, "lib") }.freeze

  # Read the header of each image, without decoding it.
  #
  # @param files [Array<MediaFile::Image>] The images.
  # @return [Array<Hash>] For each image, its width, height, bands, interpretation, n_pages, delay,
  #   has_embedded_profile, and full_decode_size, or the error if libvips couldn't read it.
  def self.header(files)
    run("header", files).zip(files).map do |header, file|
      next header if header[:error]

      # Orientations 5-8 rotate the image by 90 or 270 degrees, which swaps the width and height.
      width, height = header.values_at(:width, :height)
      width, height = height, width if rotate?(file) && header[:orientation].to_i.between?(5, 8)

      header.merge(width:, height:, full_decode_size: full_decode_size(header, file))
    end
  end

  # Decode each image, to check whether it's corrupt and to calculate its pixel hash. For animated images, only the
  # first frame is decoded.
  #
  # @param files [Array<MediaFile::Image>] The images.
  # @return [Array<Hash>] For each image, its pixel hash, or the error if it's corrupt.
  def self.decode(files)
    run("decode", files, load: { fail: true })
  end

  # Resize an image to several sizes with one command.
  #
  # @param file [MediaFile::Image] The image.
  # @param outputs [Array<Hash>] For each output, the `file` to write to, its `width` and `height`, how to `resize` it
  #   ("thumbnail" or "scale"), the `options` for `Vips::Image#thumbnail_image`, and the `save_options` for its format.
  # @raise [Error] If the image couldn't be resized.
  def self.thumbnail(file, outputs)
    outputs = outputs.map { |output| output.except(:file).merge(path: output[:file].path) }
    result = run("thumbnail", [file], outputs:, write: outputs.pluck(:path)).first
    raise Error, "couldn't resize #{file.file.path}: #{result[:error]}" if result[:error]
  end

  # @return [Integer] The number of bytes needed to decode the whole image in memory, or 0 if it can be decoded as a
  #   stream. Interlaced PNGs and PNGs with an orientation flag can't be decoded as a stream.
  def self.full_decode_size(header, file)
    return 0 unless file.file_ext == :png && (header[:interlaced] || header[:orientation].to_i > 1)

    bytes_per_band = (header[:format] == "ushort") ? 2 : 1
    header[:width] * header[:height] * header[:bands] * bytes_per_band
  end

  # @return [Boolean] True if the worker should rotate the image according to its orientation flag. PNGs can't be
  #   rotated while loading, unlike JPEGs. Other formats aren't rotated, because browsers don't rotate them either.
  def self.rotate?(file)
    file.file_ext == :png
  end

  # @return [Hash] The options for loading the file with `Vips::Image.new_from_file`. Images are read as a stream, which
  #   uses less memory. JPEGs are rotated while loading.
  def self.load_options(file)
    { access: :sequential, autorotate: (true if file.file_ext == :jpg) }.compact
  end

  # Run the worker with the same Ruby as Rails, so it can load the same gems. Each file is sent as a separate argument,
  # because a single argument can't be longer than 128KB.
  #
  # @param load [Hash] Extra options for loading the files.
  # @param write [Array<String>] The files the worker can write to.
  # @param fields [Hash] Extra fields to send with each file.
  # @return [Array<Hash>] The result for each file.
  # @raise [Error] If the worker failed, timed out, or returned an invalid response.
  def self.run(operation, files, load: {}, write: [], **fields)
    return [] if files.empty?

    requests = files.map { { path: it.file.path, options: load_options(it).merge(load), rotate: rotate?(it), **fields }.to_json }
    command = [RbConfig.ruby, "--disable-gems", *LOAD_PATH.map { "-I#{it}" }, WORKER, operation, *requests].shelljoin
    env = Danbooru.config.disable_file_sandbox?.to_s.truthy? ? NO_ORC_ENV : {}
    output, status = ExternalCommand.run(command, read: [WORKER, *LOAD_PATH, *files.map { it.file.path }], write:, env:)
    raise Error, "libvips worker failed: #{output.strip}" unless status.success?

    results = JSON.parse(output.lines.last.to_s, symbolize_names: true)
    raise Error, "libvips worker returned an invalid response: #{output.strip}" unless results.is_a?(Array) && results.size == files.size && results.all?(Hash)

    results
  rescue JSON::ParserError
    raise Error, "libvips worker returned an invalid response: #{output.strip}"
  rescue ExternalCommand::TimeoutError, ExternalCommand::OutputLimitError => e
    raise Error, e.message.sub(/\A\S+/, "libvips worker")
  end

  private_class_method :full_decode_size, :rotate?, :load_options, :run
end
