require "test_helper"

module Source::Tests::Extractor
  class ForiioExtractorTest < ActiveSupport::TestCase
    context "A Foriio post with a single image" do
      strategy_should_work(
        "https://www.foriio.com/works/364622",
        image_urls: %w[https://foriio.imgix.net/store/387d11df83ebbb2301041a7f88630bbf.jpg],
        media_files: [{ file_size: 2_120_678 }],
        page_url: "https://www.foriio.com/works/364622",
        profile_url: "https://www.foriio.com/mokoxmoko2",
        profile_urls: %w[https://www.foriio.com/mokoxmoko2 https://twitter.com/gumaguma_m],
        display_name: "moko",
        username: "mokoxmoko2",
        other_names: ["moko", "mokoxmoko2"],
        dtext_artist_commentary_title: "221004 2",
        dtext_artist_commentary_desc: "",
      )
    end

    context "A Foriio post with multiple images" do
      strategy_should_work(
        "https://www.foriio.com/works/698354",
        image_urls: %w[
          https://foriio.imgix.net/store/41024334e0f3ba13b6172ce722950792.png
          https://foriio.imgix.net/store/a3e79def565b400857c85dafbddb5e19.png
          https://foriio.imgix.net/store/51d07a9abe73f5bc1cb41db28ecca36f.png
        ],
        media_files: [
          { file_size: 3_500_873 },
          { file_size: 1_656_158 },
          { file_size: 2_371_766 },
        ],
        page_url: "https://www.foriio.com/works/698354",
        profile_urls: %w[https://www.foriio.com/yumenkmc https://twitter.com/yumenkmc],
        display_name: "𝗇𝖾𝗄𝗈𝗆𝗈🐾",
        username: "yumenkmc",
        tags: [],
        dtext_artist_commentary_title: "おどロボ / 海茶 feat. 琴葉姉妹 with ずんだもん - MV用イラスト・ドットアニメーション",
        dtext_artist_commentary_desc: <<~EOS.chomp,
          海茶さんの「おどロボ / 琴葉姉妹 with ずんだもん」のMV用イラストとピクセルアートを制作させていただきました。

          ボカコレ2023夏 ルーキーランキング1位作品

          N⇢
          https://www.nicovideo.jp/watch/sm42574301

          Y⇢
          https://youtu.be/D_UC0WJmLnc
        EOS
      )
    end

    context "A R-18 Foriio post" do
      strategy_should_work(
        "https://www.foriio.com/works/508125",
        image_urls: %w[
          https://foriio.imgix.net/store/01f09d1d779b8e0e7c6727e841e8960e.jpg
          https://foriio.imgix.net/store/a7d800ca622c7b83ca691bc098ee5430.jpg
        ],
        media_files: [
          { file_size: 959_217 },
          { file_size: 1_018_206 },
        ],
        page_url: "https://www.foriio.com/works/508125",
        profile_url: "https://www.foriio.com/piyu-ruru",
        profile_urls: %w[https://www.foriio.com/piyu-ruru https://twitter.com/piyu_ruru],
        display_name: "ぴゆるる",
        username: "piyu-ruru",
        other_names: ["ぴゆるる", "piyu-ruru"],
        dtext_artist_commentary_title: "●●★●●●●● / Sample",
        dtext_artist_commentary_desc: <<~EOS.chomp,
          Skeb向けサンプル① / 脱ぎ差分

          Sample for NSFW Skeb requests①
          take off difference
        EOS
      )
    end

    context "A deleted Foriio post" do
      strategy_should_work(
        "https://www.foriio.com/works/275072",
        image_urls: [],
        page_url: "https://www.foriio.com/works/275072",
        profile_url: nil,
        profile_urls: %w[],
        display_name: nil,
        username: nil,
        other_names: [],
        dtext_artist_commentary_title: "",
        dtext_artist_commentary_desc: "",
      )
    end
  end
end
