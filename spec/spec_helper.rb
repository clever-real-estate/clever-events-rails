# frozen_string_literal: true

require "clever_events_rails"

spec = Gem::Specification.find_by_name("clever_events_rails")
gem_root = spec.gem_dir

helpers = Dir[File.join(gem_root, "spec", "support", "**", "*.rb")]
helpers.each { |f| require f }

RSpec.configure do |config|
  # Enable flags like --only-failures and --next-failure
  config.example_status_persistence_file_path = ".rspec_status"

  # Disable RSpec exposing methods globally on `Module` and `main`
  config.disable_monkey_patching!

  config.expect_with :rspec do |c|
    c.syntax = :expect
  end
end
