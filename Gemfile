source "https://rubygems.org/"

ruby "~> 4.0.6"

gem "rails", "~> 8", ">= 8.1.3.1"
gem "pg", "~> 1"
gem "simple_form", "~> 5", ">= 5.4.1"
gem "sanitize", "~> 7"
gem "ruby-vips", "~> 2", ">= 2.3.0"
gem "diff-lcs", "~> 2", require: false
gem "bcrypt", "~> 3", require: "bcrypt"
gem "aws-sdk-sqs", "~> 1", ">= 1.117.0"
gem "responders", "~> 3", ">= 3.2.0"
gem "dtext_rb", path: "lib/dtext_rb", require: "dtext"
gem "memoist", "~> 0.16", ">= 0.16.2"
gem "daemons", "~> 1", ">= 1.4.1"
gem "bootsnap", "~> 1", require: false
gem "addressable", "~> 2", ">= 2.9.0"
gem "rakismet", "~> 1", ">= 1.5.4"
gem "activemodel-serializers-xml", "~> 1", ">= 1.0.3"
gem "shakapacker", "~> 10"
gem "rake", "~> 13", ">= 13.4.2"
gem "redis", "~> 6"
gem "builder", "~> 3", ">= 3.3.0"
# gem 'did_you_mean' # github.com/yuki24/did_you_mean/issues/117
gem "puma", "~> 7"
gem "scenic", "~> 1", ">= 1.9.0"
gem "ipaddress_2", "~> 0.14"
gem "http", "~> 6"
gem "pundit", "~> 2", ">= 2.5.2"
gem "mail", "~> 2", ">= 2.9.1"
gem "nokogiri", "~> 1"
gem "view_component", "~> 4", ">= 4.12.0"
gem "tzinfo-data", "~> 1", ">= 1.2026.3"
gem "hsluv", "~> 1", ">= 1.0.2"
gem "google-cloud-bigquery", "~> 1", ">= 1.64.0", require: "google/cloud/bigquery"
gem "google-cloud-storage", "~> 1", ">= 1.62.0", require: "google/cloud/storage"
gem "clockwork", "~> 4", ">= 4.0.1"
gem "puma_worker_killer", "~> 1"
gem "rack-timeout", "~> 0.7", require: "rack/timeout/base"
gem "rackup", "~> 2", ">= 2.3.1"
gem "ffi", "~> 1"
gem "rbtrace", "~> 0.5", ">= 0.5.5"
gem "good_job", "~> 4", ">= 4.19.2"
gem "crass", "~> 1", ">= 1.0.7"
gem "public_suffix", "~> 7", ">= 7.0.5"
gem "debug", "~> 1", ">= 1.11.1"
gem "faker", "~> 3", ">= 3.8.0"
gem "resolv", "~> 0.7", ">= 0.7.1"
gem "rover-df", "~> 1", ">= 1.0.1"
gem "ffi-libarchive", "~> 1", ">= 1.1.14"
gem "pry-rails", "~> 0.3", ">= 0.3.11"
gem "drb", "~> 2", ">= 2.2.3"
gem "net-sftp", "~> 4"
gem "rbnacl", "~> 7", ">= 7.1.2"
gem "x25519", "~> 1", ">= 1.0.11"
gem "ed25519", "~> 1"
gem "bcrypt_pbkdf", "~> 1"
gem "connection_pool", "~> 3", ">= 3.0.2"
gem "rotp", "~> 6", ">= 6.3.0"
gem "rqrcode", "~> 3", ">= 3.2.0"
gem "kramdown", "~> 2", ">= 2.5.2"
gem "abbrev", "~> 0.1", ">= 0.1.2"
gem "rubyzip", "~> 3", ">= 3.4.1", require: false
gem "webrick", "~> 1", ">= 1.9.2"
gem "useragent", "~> 0.16", ">= 0.16.11"
gem "dotenv-rails", "~> 3", ">= 3.2.0", require: false # This is loaded in application.rb
gem "benchmark", "~> 0.5"

group :development do
  gem "rubocop", "~> 1", ">= 1.89.0", require: false
  gem "rubocop-rails", "~> 2", ">= 2.36.0", require: false
  gem "rubocop-factory_bot", "~> 2", ">= 2.28.0", require: false
  # gem 'meta_request'
  gem "rack-mini-profiler", "~> 4", ">= 4.0.1"
  gem "stackprof", "~> 0.2", ">= 0.2.28"
  gem "flamegraph", "~> 0.9"
  gem "memory_profiler", "~> 1", ">= 1.1.0"
  gem "better_errors", "~> 2", ">= 2.10.1"
  gem "binding_of_caller", "~> 2"
  gem "benchmark-ips", "~> 2", ">= 2.15.1", require: "benchmark/ips"
  gem "listen", "~> 3", ">= 3.10.0"
  gem "derailed_benchmarks", "~> 2", ">= 2.2.1"
  gem "ruby-lsp-shoulda-context", "~> 0.4", ">= 0.4.9", require: false
end

group :test do
  gem "shoulda-context", "~> 2"
  gem "shoulda-matchers", "~> 8", ">= 8.0.1"
  gem "factory_bot", "~> 6", ">= 6.6.0"
  gem "mocha", "~> 3", ">= 3.1.0", require: "mocha/minitest"
  gem "simplecov", "~> 1", ">= 1.1.0", require: false
  gem "simplecov-cobertura", "~> 4", require: false
  gem "minitest", "~> 6", ">= 6.0.6"
  gem "minitest-reporters", "~> 1", ">= 1.8.0", require: "minitest/reporters"
  gem "mock_redis", "~> 0", ">= 0.55.0"
  gem "capybara", "~> 3", ">= 3.40.0"
  gem "selenium-webdriver", "~> 4", ">= 4.47.0"
  gem "testcontainers-core", "~> 0", ">= 0.2.0", require: false
end
