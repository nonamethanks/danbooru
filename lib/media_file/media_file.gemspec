# frozen_string_literal: true

require_relative "lib/media_file/version"

Gem::Specification.new do |spec|
  spec.name          = "media_file"
  spec.version       = MediaFileLib::VERSION
  spec.authors       = ["evazion", "nonamethanks"]
  spec.email         = ["noizave@gmail.com", "hellafrickingepic@gmail.com"]

  spec.summary       = "Danbooru media file utils"
  spec.description   = "Standalone media file utility classes used by Danbooru projects"
  spec.homepage      = "https://github.com/danbooru/danbooru"
  spec.license       = "MIT"

  spec.required_ruby_version = ">= 4.0.2"

  spec.files = Dir.chdir(__dir__) do
    Dir["lib/**/*.rb", "test/**/*.rb", "Gemfile", "media_file.gemspec"]
  end
  spec.require_paths = ["lib"]
  spec.metadata["rubygems_mfa_required"] = "true"
end
