# frozen_string_literal: true

class Source::URL::Vgen < Source::URL
  site "Vgen", url: "https://vgen.co", domains: %w[vgen.co googleapis.com]

  RESERVED_USERNAMES = %w[about artists blog c catalogue category commission dashboard explore faq for-artists help login messages notifications privacy search settings shop signup terms-of-service uploads]

  attr_reader :username, :showcase_id, :service_id, :user_id, :concept_id, :file_id, :kind

  def self.match?(url)
    url.domain == "vgen.co" || (url.host == "storage.googleapis.com" && url.path.start_with?("/vgen-production-storage/"))
  end

  def parse
    segments = path_segments.dup
    segments.shift if domain == "googleapis.com" && segments.first == "vgen-production-storage"

    case [domain, *segments]

    # https://storage.vgen.co/uploads/71595670-9147-4f5d-bbf8-c4c6cf71c4c7/portfolio/865ceac0-1d54-40ea-8f38-26147a8af916.webp (full)
    # https://storage.googleapis.com/vgen-production-storage/uploads/b9813a9f-98c7-4eaa-881d-16a70fe41134/portfolio/60aeb8d1-0fcc-4c15-8d8e-c64dc1a845b8-thumbnail.webp (sample)
    in _, "uploads", user_id, "portfolio", /\A(.+?)(?:-thumbnail)?(\.\w+)\z/ => file
      @user_id = user_id
      @file_id = "#{$1}#{$2}"
      @kind = :portfolio

    # https://storage.googleapis.com/vgen-production-storage/uploads/b9813a9f-98c7-4eaa-881d-16a70fe41134/services/f8ab860e-6e88-435b-9979-bd42d1091733.webp (full)
    # https://storage.googleapis.com/vgen-production-storage/uploads/b9813a9f-98c7-4eaa-881d-16a70fe41134/services/f8ab860e-6e88-435b-9979-bd42d1091733-service-thumbnail-default.webp (sample)
    in _, "uploads", user_id, "services", /\A(.+?)(?:-service-thumbnail-default)?(\.\w+)\z/ => file
      @user_id = user_id
      @file_id = "#{$1}#{$2}"
      @kind = :service

    # https://storage.googleapis.com/vgen-production-storage/uploads/characters/34446b10-4157-46bf-a4cf-21139b9a3bc5/concepts/51d85aaf-a389-45c8-b595-8d9a72dd28d5/references/bdd472b6-d43c-4f9f-bf46-755388be8fff.webp
    in _, "uploads", "characters", char_id, "concepts", concept_id, "references", file
      @user_id = char_id
      @concept_id = concept_id
      @file_id = file
      @kind = :character

    # https://vgen.co/off_grid04/portfolio/showcase/pomu/97062906-f6b7-4378-a945-b44be0878356
    in "vgen.co", username, "portfolio", "showcase", *_title, showcase_id unless username.in?(RESERVED_USERNAMES)
      @username = username
      @showcase_id = showcase_id

    # https://vgen.co/off_grid04/service/skeb-like-surprise-me-/3015f883-3240-43ce-845a-2a6957324e7c
    in "vgen.co", username, "service", *_title, service_id unless username.in?(RESERVED_USERNAMES)
      @username = username
      @service_id = service_id

    # https://vgen.co/off_grid04
    # https://vgen.co/off_grid04/portfolio
    # https://vgen.co/a4492e52-aec3-4da4-bffe-836fd5db8e38 (permalink; redirects to the artist's username)
    in "vgen.co", username, *_rest unless username.in?(RESERVED_USERNAMES)
      @username = username

    else
      nil
    end
  end

  def full_image_url
    case kind
    when :portfolio
      "https://storage.vgen.co/uploads/#{user_id}/portfolio/#{file_id}"
    when :service
      "https://storage.vgen.co/uploads/#{user_id}/services/#{file_id}"
    when :character
      "https://storage.vgen.co/uploads/characters/#{user_id}/concepts/#{concept_id}/references/#{file_id}"
    end
  end

  def page_url
    if username.present? && showcase_id.present?
      "https://vgen.co/#{username}/portfolio/showcase/x/#{showcase_id}"
    elsif username.present? && service_id.present?
      "https://vgen.co/#{username}/service/x/#{service_id}"
    end
  end

  def profile_url
    "https://vgen.co/#{username}" if username.present?
  end
end
