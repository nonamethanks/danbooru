require "test_helper"

module Source::Tests::URL
  class VgenUrlTest < ActiveSupport::TestCase
    context "Vgen URLs" do
      should be_image_url(
        "https://storage.vgen.co/uploads/71595670-9147-4f5d-bbf8-c4c6cf71c4c7/portfolio/865ceac0-1d54-40ea-8f38-26147a8af916.webp",
        "https://storage.googleapis.com/vgen-production-storage/uploads/b9813a9f-98c7-4eaa-881d-16a70fe41134/portfolio/60aeb8d1-0fcc-4c15-8d8e-c64dc1a845b8.webp",
        "https://storage.googleapis.com/vgen-production-storage/uploads/b9813a9f-98c7-4eaa-881d-16a70fe41134/portfolio/60aeb8d1-0fcc-4c15-8d8e-c64dc1a845b8-thumbnail.webp",
        "https://storage.googleapis.com/vgen-production-storage/uploads/b9813a9f-98c7-4eaa-881d-16a70fe41134/services/f8ab860e-6e88-435b-9979-bd42d1091733.webp",
        "https://storage.googleapis.com/vgen-production-storage/uploads/b9813a9f-98c7-4eaa-881d-16a70fe41134/services/f8ab860e-6e88-435b-9979-bd42d1091733-service-thumbnail-default.webp",
        "https://storage.googleapis.com/vgen-production-storage/uploads/characters/34446b10-4157-46bf-a4cf-21139b9a3bc5/concepts/51d85aaf-a389-45c8-b595-8d9a72dd28d5/references/bdd472b6-d43c-4f9f-bf46-755388be8fff.webp",
      )

      should be_page_url(
        "https://vgen.co/off_grid04/portfolio/showcase/pomu/97062906-f6b7-4378-a945-b44be0878356",
        "https://vgen.co/off_grid04/service/skeb-like-surprise-me-/3015f883-3240-43ce-845a-2a6957324e7c",
      )

      should be_profile_url(
        "https://vgen.co/off_grid04",
        "https://vgen.co/off_grid04/portfolio",
        "https://vgen.co/a4492e52-aec3-4da4-bffe-836fd5db8e38",
      )
    end

    should parse_url(
      "https://storage.googleapis.com/vgen-production-storage/uploads/b9813a9f-98c7-4eaa-881d-16a70fe41134/portfolio/60aeb8d1-0fcc-4c15-8d8e-c64dc1a845b8-thumbnail.webp",
    ).into(
      full_image_url: "https://storage.vgen.co/uploads/b9813a9f-98c7-4eaa-881d-16a70fe41134/portfolio/60aeb8d1-0fcc-4c15-8d8e-c64dc1a845b8.webp",
    )

    should parse_url(
      "https://storage.googleapis.com/vgen-production-storage/uploads/b9813a9f-98c7-4eaa-881d-16a70fe41134/services/f8ab860e-6e88-435b-9979-bd42d1091733-service-thumbnail-default.webp",
    ).into(
      full_image_url: "https://storage.vgen.co/uploads/b9813a9f-98c7-4eaa-881d-16a70fe41134/services/f8ab860e-6e88-435b-9979-bd42d1091733.webp",
    )

    should parse_url("https://vgen.co/off_grid04/portfolio/showcase/pomu/97062906-f6b7-4378-a945-b44be0878356").into(
      username: "off_grid04", showcase_id: "97062906-f6b7-4378-a945-b44be0878356", site_name: "Vgen",
    )

    should parse_url("https://vgen.co/off_grid04/service/skeb-like-surprise-me-/3015f883-3240-43ce-845a-2a6957324e7c").into(
      username: "off_grid04", service_id: "3015f883-3240-43ce-845a-2a6957324e7c",
    )

    should_not be_profile_url("https://vgen.co/catalogue/illustrations")
  end
end
