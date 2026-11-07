# frozen_string_literal: true

# A MediaFile for a JPEG, PNG, GIF, WebP, or AVIF file. Uses libvips in a sandbox (see Danbooru::Vips) for reading and
# resizing images.
class MediaFile::Image < MediaFile
  # The options for saving previews in each format.
  #
  # @see https://www.libvips.org/API/current/VipsForeignSave.html
  SAVE_OPTIONS = {
    jpeg: { strip: true, interlace: true, optimize_coding: true, optimize_scans: true, trellis_quant: true, overshoot_deringing: true, quant_table: 3 },
    webp: { preset: :drawing, smart_subsample: false, effort: 4, strip: true },
    avif: { compression: :av1, effort: 4, strip: true },
  }.freeze

  def close
    super
    @preview_frame&.close unless @preview_frame == self
    @preview_frame = nil
  end

  # @return [Array<(Integer, Integer)>] The width and height, from the image's header, or from its EXIF metadata if libvips
  #   can't read it.
  def dimensions
    if header[:error]
      [metadata.width, metadata.height]
    else
      header.values_at(:width, :height)
    end
  end

  def is_supported?
    case file_ext
    when :avif
      !metadata.is_rotated? && !metadata.is_mirrored? && !metadata.is_cropped? && !metadata.is_grid_image? && !metadata.has_auxiliary_image? && !metadata.is_animated_avif?
    else
      true
    end
  end

  def is_corrupt?
    error.present?
  end

  # XXX we should check if animated gifs can be successfully decoded, but ffmpeg sometimes returns errors for seemingly
  # good gifs, and no errors for known corrupted gifs.
  def error
    decoded[:error]
  end

  # Interlaced PNGs and PNGs with an orientation flag can't be decoded as a stream, so the whole image is decoded in
  # memory. This only reads the header, so it's safe to call before validating the file.
  def full_decode_size
    header[:full_decode_size].to_i
  end

  def metadata
    super.merge({ "Vips:Error" => error }.compact_blank)
  end

  def duration
    return nil if !is_animated?

    # XXX ffmpeg 7.1 calculates duration incorrectly for some gif and webp files.
    case file_ext
    when :gif, :webp
      vips_duration
    else
      ffmpeg_duration
    end
  end

  def frame_count
    case file_ext
    when :gif, :webp
      n_pages
    when :png
      exif_metadata.fetch("PNG:AnimationFrames", 1)
    when :avif
      video.frame_count
    else
      nil
    end
  end

  # @return [Integer, nil] The duration of the animation as calculated by libvips, or possibly nil if the file
  #   isn't animated or is corrupt. Note that libvips and ffmpeg may disagree on the duration.
  def vips_duration
    # XXX Browsers typically raise the frame time to 0.1s if it's less than or equal to 0.01s.
    header[:delay]&.map { |delay| (delay <= 10) ? 100 : delay }&.sum&./(1000.0)
  end

  # @return [Integer, nil] The duration of the animation as calculated by ffmpeg, or possibly nil if the file
  #   isn't animated or is corrupt. Note that libvips and ffmpeg may disagree on the duration.
  def ffmpeg_duration
    video.duration
  end

  # @return [Integer, nil] The frame count for gif and webp images, or possibly nil if the file doesn't have a frame count or is corrupt.
  def n_pages
    header[:n_pages]
  end

  def frame_rate
    return nil if !is_animated? || frame_count.nil? || duration.nil? || duration == 0
    frame_count / duration
  end

  def channels
    header[:bands]
  end

  def colorspace
    header[:interpretation]&.to_sym
  end

  # Resize the image to exactly the given width and height.
  #
  # @return [MediaFile::Image] The resized image.
  def resize!(width, height, format: :jpeg, quality: 85)
    resize_all([{ width:, height:, format:, quality: }]).first
  end

  # Resize the image to several sizes with one command.
  #
  # @param sizes [Array<Hash>] The exact `width` and `height` of each resized image, and its `format` and `quality`.
  # @return [Array<MediaFile::Image>] The resized images.
  def resize_all(sizes)
    return [] if sizes.empty?

    # Check all the formats before creating any files, so they aren't left open if one of them is unsupported.
    outputs = sizes.map do |size|
      format = size.fetch(:format, :jpeg).to_sym
      save_options = SAVE_OPTIONS.fetch(format) { raise NotImplementedError, "can't resize to #{format}" }
      { width: size.fetch(:width), height: size.fetch(:height), format:, **resize_options, save_options: { Q: size.fetch(:quality, 85), **save_options }}
    end

    outputs = outputs.map { |output| output.except(:format).merge(file: Danbooru::Tempfile.new(["danbooru-image-preview-#{md5}-", ".#{output[:format]}"])) }
    Danbooru::Vips.thumbnail(self, outputs)
    outputs.map { MediaFile::Image.new(it[:file]) }
  rescue StandardError
    outputs&.each { it[:file]&.close }
    raise
  end

  # @param sizes [Array<Hash>] The max `width` and `height` of each preview, and its `format` and `quality`.
  # @return [Array<MediaFile::Image>] The previews, sized to fit within each width and height.
  def previews(sizes)
    return [] if sizes.empty?
    raise Danbooru::Vips::Error, "libvips can't read #{file.path}" if width.nil? || height.nil?

    preview_frame.resize_all(sizes.map do |size|
      width, height = MediaFile.scale_dimensions(self.width, self.height, size[:width], size[:height])
      size.merge(width:, height:)
    end)
  end

  def preview!(max_width, max_height, **options)
    previews([{ width: max_width, height: max_height, **options }]).first
  end

  def is_animated?
    frame_count.to_i > 1
  end

  def is_animated_gif?
    file_ext == :gif && is_animated?
  end

  def is_animated_png?
    file_ext == :png && is_animated?
  end

  def is_animated_webp?
    file_ext == :webp && is_animated?
  end

  def is_animated_avif?
    file_ext == :avif && is_animated?
  end

  # Return true if the image has an embedded ICC color profile.
  def has_embedded_profile?
    header[:has_embedded_profile] == true
  end

  # @return [String] The MD5 hash of the image's pixels (see Danbooru::Vips), or the MD5 of the file if the image is
  #   animated or corrupt.
  def pixel_hash
    return md5 if is_animated?

    decoded[:pixel_hash] || md5
  end

  private

  # @return [Hash] The image's header (see Danbooru::Vips.header).
  memoize def header
    Danbooru::Vips.header([self]).first
  end

  # @return [Hash] The image's pixel hash, or its error if it's corrupt (see Danbooru::Vips.decode).
  memoize def decoded
    Danbooru::Vips.decode([self]).first
  end

  # @return [Hash] How to resize the image with bin/vips-worker, depending on its colorspace and color profile.
  #
  # @see https://www.libvips.org/API/current/Using-vipsthumbnail.md.html
  # @see https://www.libvips.org/API/current/libvips-resample.html#vips-thumbnail
  def resize_options
    raise Danbooru::Vips::Error, "libvips can't read #{file.path}" if header[:error]

    if colorspace.in?(%i[srgb rgb16])
      { resize: "thumbnail", options: { size: :force, import_profile: "srgb", export_profile: "srgb" }}
    elsif colorspace == :cmyk && has_embedded_profile?
      { resize: "thumbnail", options: { size: :force, import_profile: "cmyk", export_profile: "srgb" }}
    elsif colorspace == :cmyk
      # Leave CMYK without a profile as CMYK to avoid distorting the colors by converting it to sRGB.
      { resize: "scale", options: {}}
    elsif colorspace.in?(%i[b-w grey16]) && has_embedded_profile?
      # Convert greyscale to sRGB so that the color profile is properly applied before we strip it.
      { resize: "thumbnail", options: { size: :force, export_profile: "srgb" }}
    elsif colorspace.in?(%i[b-w grey16])
      # Otherwise, leave greyscale without a profile as greyscale because converting it to sRGB would change it from 1
      # channel to 3 channels.
      { resize: "thumbnail", options: { size: :force }}
    else
      raise NotImplementedError, "can't resize images with the #{colorspace.inspect} colorspace"
    end
  end

  def video
    FFmpeg.new(self)
  end

  def preview_frame
    if is_animated?
      @preview_frame ||= video.smart_video_preview || self
    else
      @preview_frame ||= self
    end
  end

  memoize :video, :dimensions, :error, :metadata, :is_corrupt?, :is_animated_gif?, :is_animated_png?
end
