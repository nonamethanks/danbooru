# frozen_string_literal: true

# @see Source::URL::Vgen
class Source::Extractor::Vgen < Source::Extractor
  def image_urls
    if parsed_url.full_image_url.present?
      [parsed_url.full_image_url]
    elsif showcase.present?
      showcase["showcaseItems"].to_a.pluck("url")
    elsif service.present?
      service["galleryItems"].to_a.pluck("url")
    else
      []
    end
  end

  def profile_url
    "https://vgen.co/#{username}" if username.present?
  end

  def profile_urls
    [profile_url, *page_user["socials"]&.pluck("link")].compact_blank
  end

  def display_name
    moderation["displayName"] || page_user["displayName"]
  end

  def username
    moderation["username"] || page_user["username"] || parsed_url.username || parsed_referer&.username
  end

  def artist_commentary_title
    showcase["title"] || service["serviceName"]
  end

  def artist_commentary_desc
    showcase["description"] || service["description"]
  end

  def dtext_artist_commentary_desc
    DText.from_plaintext(plain_commentary_desc)
  end

  def tags
    (showcase["tags"] || service["tags"]).to_a.map { |tag| [tag, nil] }
  end

  def showcase_id
    parsed_url.showcase_id || parsed_referer&.showcase_id
  end

  def service_id
    parsed_url.service_id || parsed_referer&.service_id
  end

  def showcase
    return {} if showcase_id.blank?

    page_props["linkedShowcase"] || {}
  end

  def service
    return {} if service_id.blank?

    page_props["linkedService"] || {}
  end

  def moderation
    showcase["userModeration"] || service["userModeration"] || {}
  end

  def page_user
    page_props["user"] || {}
  end

  def page_props
    page_json.dig("props", "pageProps") || {}
  end

  memoize def page_json
    script = page&.at_css("script#__NEXT_DATA__")&.text
    script&.parse_json || {}
  end

  memoize def page
    http.cache(1.minute).parsed_get(page_url)
  end

  # Flatten a Vgen rich-text description (a JSON-encoded array of Slate.js nodes) into plain text.
  def plain_commentary_desc
    nodes = artist_commentary_desc.to_s.parse_json
    nodes.to_a.map { |node| self.class.slate_block_text(node) }.join("\n")
  end

  def self.slate_block_text(node)
    if node["type"].in?(%w[bulleted-list numbered-list])
      node["children"].to_a.map { |item| "* #{slate_leaf_text(item)}" }.join("\n")
    else
      slate_leaf_text(node)
    end
  end

  def self.slate_leaf_text(node)
    if node.key?("text")
      node["text"].to_s
    else
      node["children"].to_a.map { |child| slate_leaf_text(child) }.join
    end
  end
end
