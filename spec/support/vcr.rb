# frozen_string_literal: true

VCR.configure do |config|
  spec = Gem::Specification.find_by_name("clever_events_rails")
  gem_root = spec.gem_dir

  config.cassette_library_dir = File.join(gem_root, "spec", "support", "cassettes")
  config.hook_into :webmock
  config.ignore_localhost = true
  config.configure_rspec_metadata!
  config.allow_http_connections_when_no_cassette = false
  debug_log_file = File.join(gem_root, "spec", "dummy_app", "log", "vcr.log")
  config.debug_logger = File.open(debug_log_file, "w") if ENV["VCR_DEBUG"]
end
