require "test_helper"

class DanbooruVipsTest < ActiveSupport::TestCase
  # Count how many external commands the block runs.
  def count_commands
    run = ExternalCommand.method(:run)
    count = 0
    ExternalCommand.define_singleton_method(:run) do |*args, **options|
      count += 1
      run.call(*args, **options)
    end

    yield
    count
  ensure
    ExternalCommand.define_singleton_method(:run, run)
  end

  context "Danbooru::Vips.header" do
    should "return the header of each image" do
      jpg = MediaFile.open("test/files/jpg/test.jpg")
      png = MediaFile.open("test/files/png/test.png")
      headers = Danbooru::Vips.header([jpg, png])

      assert_equal([jpg.width, jpg.height], headers.first.values_at(:width, :height))
      assert_equal([png.width, png.height], headers.second.values_at(:width, :height))
    end

    should "return an error for files that libvips can't read" do
      Tempfile.create do |file|
        file.write("not an image")
        file.flush
        header = Danbooru::Vips.header([MediaFile::Image.new(file)]).first

        assert_equal("libvips error", header[:error])
      end
    end

    should "return the rotated dimensions of PNGs with an orientation flag" do
      header = Danbooru::Vips.header([MediaFile.open("test/files/png/test-rotation-good-chunk.png")]).first

      assert_equal([64, 128], header.values_at(:width, :height))
    end
  end

  context "the libvips worker" do
    should "not load file types we don't support" do
      Danbooru::Tempfile.create(["danbooru-test-", ".ppm"]) do |file|
        file.write("P5\n1 1\n255\n\x00")
        file.flush

        assert_equal("libvips error", Danbooru::Vips.header([MediaFile::Image.new(file)]).first[:error])
      end
    end

    should "load file types we support" do
      files = %w[jpg/test.jpg png/test.png gif/test.gif webp/test.webp avif/paris_icc_exif_xmp.avif].map { MediaFile.open("test/files/#{it}") }

      Danbooru::Vips.header(files).zip(files).each do |header, file|
        assert_operator(header[:width].to_i, :>, 0, file.file.path)
      end
    end
  end

  context "Danbooru::Vips.decode" do
    should "return the pixel hash and error of each image in one command" do
      files = %w[test/files/dupes/countergirl-baseline.jpg test/files/dupes/countergirl-grey.png test/files/jpg/test-blank.jpg].map { MediaFile.open(it) }
      results = nil
      commands = count_commands { results = Danbooru::Vips.decode(files) }

      assert_equal(1, commands)
      assert_equal(["c135caa2229b6d43d06179503f70ed74", nil], results.first.values_at(:pixel_hash, :error))
      assert_equal(["d007f30f42cb7c5835fb3d0d9c24587e", nil], results.second.values_at(:pixel_hash, :error))
      assert_equal([nil, "libvips error"], results.third.values_at(:pixel_hash, :error))
    end
  end

  context "MediaFile::Image" do
    should "only run two commands to validate an image and get its metadata" do
      commands = count_commands do
        file = MediaFile.open("test/files/jpg/test.jpg")
        file.dimensions
        file.full_decode_size
        file.is_animated?
        file.channels
        file.colorspace
        file.has_embedded_profile?
        file.is_corrupt?
        file.pixel_hash
        file.duration
      end

      assert_equal(2, commands)
    end
  end

  context "MediaFile::Image#previews" do
    should "generate every preview in one command" do
      file = MediaFile.open("test/files/jpg/test.jpg")
      file.dimensions
      previews = nil
      commands = count_commands do
        previews = file.previews([
          { width: 180, height: 180, format: :jpeg, quality: 85 },
          { width: 720, height: 720, format: :webp, quality: 75 },
          { width: 850, height: 850, format: :jpeg, quality: 85 },
        ])
      end

      assert_equal(1, commands)
      assert_equal([[180, 121], [500, 335], [500, 335]], previews.map(&:dimensions))
      assert_equal(%i[jpg webp jpg], previews.map(&:file_ext))
    end

    should "generate AVIF previews" do
      skip "Not supported because libheif in the Docker image doesn't have an AV1 encoder"

      preview = MediaFile.open("test/files/jpg/test.jpg").preview!(150, 150, format: :avif)
      assert_equal(:avif, preview.file_ext)
    end

    should "flatten transparent images to a white background" do
      preview = MediaFile.open("test/files/png/alpha.png").preview!(150, 150, format: :jpeg)

      assert_equal(3, preview.channels)
    end

    should "raise an error if the image can't be resized" do
      Tempfile.create do |file|
        file.write("not an image")
        file.flush
        output = { file: Danbooru::Tempfile.new(["preview", ".jpeg"]), width: 10, height: 10, resize: "thumbnail", options: {}, save_options: {}}

        assert_raises(Danbooru::Vips::Error) { Danbooru::Vips.thumbnail(MediaFile::Image.new(file), [output]) }
      end
    end
  end

  context "MediaAsset.upload!" do
    should "run one command to generate all the variants of an image" do
      file = MediaFile.open("test/files/jpg/test.jpg")
      file.dimensions
      file.is_corrupt?
      file.metadata
      commands = count_commands { MediaAsset.upload!(file) }

      assert_equal(1, commands)
      assert_equal(%i[180x180 360x360 720x720 original], MediaAsset.last.variants.map(&:type))
    end
  end

  context "MediaFile::Ugoira" do
    should "decode all frames in one command to get the pixel hash" do
      commands = count_commands { MediaFile.open("test/files/ugoira/ugoira-95239241-danbooru.zip").pixel_hash }

      assert_equal(1, commands)
    end
  end
end
