require "test_helper"

module Source::Tests::Extractor
  class VgenExtractorTest < ActiveSupport::ExtractorTestCase
    context "A Vgen portfolio showcase" do
      strategy_should_work(
        "https://vgen.co/yongdal/portfolio/showcase/4/f25555dc-32df-481e-8240-9d3f5e89de80",
        image_urls: %w[https://storage.vgen.co/uploads/71595670-9147-4f5d-bbf8-c4c6cf71c4c7/portfolio/865ceac0-1d54-40ea-8f38-26147a8af916.webp],
        media_files: [{ file_size: 889_294 }],
        page_url: "https://vgen.co/yongdal/portfolio/showcase/x/f25555dc-32df-481e-8240-9d3f5e89de80",
        profile_url: "https://vgen.co/yongdal",
        display_name: "yongdal",
        username: "yongdal",
        tags: %w[illustration fanart],
        artist_commentary_title: "4",
        dtext_artist_commentary_desc: "",
      )
    end

    context "A Vgen commission listing with multiple sample images" do
      strategy_should_work(
        "https://vgen.co/saraemi/service/standard-illustration-commission-full-half-background-available-/5c56b004-f737-44d7-8b5b-bcdd910b5429",
        image_urls: %w[
          https://storage.vgen.co/uploads/4384fc69-86dd-48f0-80b3-2e135d551eb3/services/292147c7-4227-452e-9a5f-9746b559bde2.webp
          https://storage.vgen.co/uploads/4384fc69-86dd-48f0-80b3-2e135d551eb3/services/d8c83582-1e3c-40a9-97b9-a4d484b68421.webp
          https://storage.vgen.co/uploads/4384fc69-86dd-48f0-80b3-2e135d551eb3/services/2189e767-cad7-4163-b06f-cb2d50fc2554.webp
          https://storage.vgen.co/uploads/4384fc69-86dd-48f0-80b3-2e135d551eb3/services/8a05bf2a-1048-4130-b7fc-5affc39cc27e.webp
        ],
        media_files: [
          { file_size: 422_424 },
          { file_size: 834_416 },
          { file_size: 375_982 },
          { file_size: 507_242 },
        ],
        page_url: "https://vgen.co/saraemi/service/x/5c56b004-f737-44d7-8b5b-bcdd910b5429",
        profile_url: "https://vgen.co/saraemi",
        display_name: "Saraemi💜✨",
        username: "saraemi",
        artist_commentary_title: "Standard Illustration Commission [Full / Half / Background Available]",
      )
    end

    context "A direct Vgen portfolio image URL with a referer" do
      strategy_should_work(
        "https://storage.googleapis.com/vgen-production-storage/uploads/71595670-9147-4f5d-bbf8-c4c6cf71c4c7/portfolio/865ceac0-1d54-40ea-8f38-26147a8af916.webp",
        referer: "https://vgen.co/yongdal/portfolio/showcase/4/f25555dc-32df-481e-8240-9d3f5e89de80",
        image_urls: %w[https://storage.vgen.co/uploads/71595670-9147-4f5d-bbf8-c4c6cf71c4c7/portfolio/865ceac0-1d54-40ea-8f38-26147a8af916.webp],
        page_url: "https://vgen.co/yongdal/portfolio/showcase/x/f25555dc-32df-481e-8240-9d3f5e89de80",
        profile_url: "https://vgen.co/yongdal",
        username: "yongdal",
      )
    end

    context "A direct Vgen image URL with no referer" do
      strategy_should_work(
        "https://storage.googleapis.com/vgen-production-storage/uploads/71595670-9147-4f5d-bbf8-c4c6cf71c4c7/portfolio/865ceac0-1d54-40ea-8f38-26147a8af916.webp",
        image_urls: %w[https://storage.vgen.co/uploads/71595670-9147-4f5d-bbf8-c4c6cf71c4c7/portfolio/865ceac0-1d54-40ea-8f38-26147a8af916.webp],
        page_url: nil,
        profile_url: nil,
        username: nil,
      )
    end

    context "A sensitive Vgen commission listing that requires a logged-in account to view" do
      strategy_should_work(
        "https://vgen.co/off_grid04/service/the-edge-of-sfw-spicy-/fdf0cbc6-ccaa-453d-898d-d503b6ea05bf",
        image_urls: [],
        page_url: "https://vgen.co/off_grid04/service/x/fdf0cbc6-ccaa-453d-898d-d503b6ea05bf",
        profile_url: "https://vgen.co/off_grid04",
        username: "off_grid04",
      )
    end
  end
end
