require "test_helper"

module Source::Tests::Extractor
  class ArtistreeExtractorTest < ActiveSupport::TestCase
    context "An Artistree image URL" do
      strategy_should_work(
        "https://dwxo6p939as9l.cloudfront.net/alysonsega/Full render (Character and/or Background/Object)/Sonicandmariotransparent-rkdqe1.png",
        image_urls: ["https://dwxo6p939as9l.cloudfront.net/alysonsega/Full render (Character and/or Background/Object)/Sonicandmariotransparent-rkdqe1.png"],
        media_files: [{ file_size: 180_714 }],
        page_url: "https://artistree.io/alysonsega",
        profile_url: "https://artistree.io/alysonsega",
        username: "alysonsega",
        dtext_artist_commentary_title: "Full render (Character and/or Background/Object)",
        dtext_artist_commentary_desc: <<~EOS.chomp,
          • Price varies on the complexity and the amount of detailed required.
          • $50 for each extra character
          • When finished, you get a high resolution .jpg file + .psd file
        EOS
      )
    end

    context "An Artistree commission listing" do
      strategy_should_work(
        "https://artistree.io/alysonsega#d23e6743-5fbe-46f8-bf5f-e6f76f74bc80",
        image_urls: [
          "https://dwxo6p939as9l.cloudfront.net/alysonsega/Full render (Character and/or Background/Object)/nielsmechanic-rkdqd6.jpg",
          "https://dwxo6p939as9l.cloudfront.net/alysonsega/Full render (Character and/or Background/Object)/Sonicandmariotransparent-rkdqe1.png",
          "https://dwxo6p939as9l.cloudfront.net/alysonsega/Full render (Character and/or Background/Object)/judynails-rkdqeu.jpg",
          "https://dwxo6p939as9l.cloudfront.net/alysonsega/Full render (Character and/or Background/Object)/reverbbf5-rkdqfv.png",
          "https://dwxo6p939as9l.cloudfront.net/alysonsega/Full render (Character and/or Background/Object)/VertWheelerPowerRagev2-rkdqgd.png",
          "https://dwxo6p939as9l.cloudfront.net/alysonsega/Full render (Character and/or Background/Object)/Vulturedesertweb-rkdqgr.png",
        ],
        media_files: [
          { file_size: 214_716 },
          { file_size: 180_714 },
          { file_size: 288_695 },
          { file_size: 143_845 },
          { file_size: 252_317 },
          { file_size: 129_077 },
        ],
        page_url: "https://artistree.io/alysonsega#d23e6743-5fbe-46f8-bf5f-e6f76f74bc80",
        profile_url: "https://artistree.io/alysonsega",
        username: "alysonsega",
        dtext_artist_commentary_title: "Full render (Character and/or Background/Object)",
        dtext_artist_commentary_desc: <<~EOS.chomp,
          • Price varies on the complexity and the amount of detailed required.
          • $50 for each extra character
          • When finished, you get a high resolution .jpg file + .psd file
        EOS
      )
    end

    context "A deleted or nonexistent Artistree commission listing" do
      strategy_should_work(
        "https://artistree.io/does-not-exist#d23e6743-5fbe-46f8-bf5f-e6f76f74bc80",
        image_urls: [],
        page_url: "https://artistree.io/does-not-exist#d23e6743-5fbe-46f8-bf5f-e6f76f74bc80",
        profile_url: "https://artistree.io/does-not-exist",
        username: "does-not-exist",
        dtext_artist_commentary_title: "",
        dtext_artist_commentary_desc: "",
      )
    end
  end
end
