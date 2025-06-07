# frozen_string_literal: true

class Source::URL::EHentai < Source::URL
  NAMESPACE_ABBREVIATIONS = { # https://ehwiki.org/wiki/Namespace
    a: "artist",
    g: "group",
    circle: "group",
    cos: "cosplayer",

    c: "character",
    char: "character",
    p: "parody",
    series: "parody",

    f: "female",
    m: "male",

    l: "language",
    lang: "language",
    x: "mixed",
    o: "other",
    r: "reclass",

  }

  def self.match?(url)
    url.domain.in?(%w[e-hentai.org exhentai.org hath.network])
  end

  def site_name
    "E-Hentai"
  end

  def parse
    case [domain, *path_segments]

    # https://exhentai.org/g/718142/c35cf33a0e/
    in ("e-hentai.org" | "exhentai.org"), "g", gallery_id, gallery_token
      @gallery_id = gallery_id
      @gallery_token = gallery_token

    # https://exhentai.org/mpv/718142/c35cf33a0e/#page3
    in ("e-hentai.org" | "exhentai.org"), "mpv", gallery_id, gallery_token
      @gallery_id = gallery_id
      @gallery_token = gallery_token
      @page_id = $1 if fragment =~ /^#page(\d+)$/

    # https://exhentai.org/s/fbb0e4348c/718142-4
    in ("e-hentai.org" | "exhentai.org"), "s", page_token, /^(\d+)-(\d+)$/
      @gallery_id = $1
      @page_id = $2
      @page_token = page_token

    # https://e-hentai.org/tag/artist:spirale
    in ("e-hentai.org" | "exhentai.org"), "tag", /^(?:(\w+):)?(\w+)\$?$/
      @tag_namespace = NAMESPACE_ABBREVIATIONS.fetch($1, $1)
      @tag_name = $2

    # https://e-hentai.org/?f_search=artist%3Aspirale
    in ("e-hentai.org" | "exhentai.org") if query&.match?(/search=(?:(\w+):)?(\w+)\$?/)
      @tag_namespace = NAMESPACE_ABBREVIATIONS.fetch($1, $1)
      @tag_name = $2

    # https://e-hentai.org/uploader/Spirale
    in ("e-hentai.org" | "exhentai.org"), *rest
      nil

    # https://lyjrkow.ksxjubvoouva.hath.network/h/416a7c19fb25549e084876f932e2f6d45a5b2d63-1215161-2400-3589-jpg/keystamp=1683990600-aab6e15ff8;fileindex=119976531;xres=2400/89931055_p0.jpg
    # https://drjvktq.miqlthdkffuu.hath.network/h/dce4b9677c8f769c12c8889e2581b989a3edd1bb-280532-642-802-png/keystamp=1683992100-6e1bddc318;fileindex=116114230;xres=org/1667196644017_fe0ug7p4.png
    in "hath.network", "h", _, params_string, _
      params = begin
        params_string.split(";").to_h { |s| s.split("=", 2) }
      rescue StandardError
        {}
      end
      @bad_link = true
      @image_sample = params["xres"] != "org"

    # https://hacaqjfrpvthigkeomjq.hath.network/om/119976531/188d8aec2d0ae17cfddf32849481385dd3303fc9-13295955-4379-6549-jpg/b09e528c8897a5a0ecb288f85fe9e9230d4a5f1c-483531-1280-1914-jpg/1280/v2f1fil8ij9dbk115c6/89931055_p0.jpg
    # https://ykofnavysaepqurqrbmv.hath.network/om/119976531/188d8aec2d0ae17cfddf32849481385dd3303fc9-13295955-4379-6549-jpg/x/0/cqq6hb0kct3sx4115c4/89931055_p0.jpg
    in "hath.network", "om", key, _, _, sample_size, _, _
      @bad_link = true
      @image_sample = sample_size != "0"

    else
      nil
    end
  end

  def page_url
    return unless @gallery_id.present?

    root = ["e-hentai.org", "exhentai.org"].include?(domain) ? domain : "e-hentai.org"

    if @page_id.present? && @page_token.present?
      "https://#{root}/s/#{@page_token}/#{@gallery_id}-#{@page_id}"
    elsif @gallery_token.present?
      "https://#{root}/g/#{@gallery_id}/#{@gallery_token}/"
    end
  end

  def tag_name
  end
end
