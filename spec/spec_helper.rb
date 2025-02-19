# frozen_string_literal: true

require "simplecov"

require "pry"
require "factory_bot"

require "clever_events_rails"

spec = Gem::Specification.find_by_name("clever_events_rails")
gem_root = spec.gem_dir

helpers = Dir[File.join(gem_root, "spec", "support", "**", "*.rb")]
helpers -= Dir[File.join(gem_root, "spec", "support", "test_models", "**", "*.rb")]
helpers.each { |f| require f }

# Configure RSpec

RSpec.configure do |config|
  # Enable flags like --only-failures and --next-failure
  config.example_status_persistence_file_path = ".rspec_status"

  # Disable RSpec exposing methods globally on `Module` and `main`
  config.disable_monkey_patching!

  config.expect_with :rspec do |c|
    c.syntax = :expect
  end

  config.include FactoryBot::Syntax::Methods

  config.before do
    ActiveRecord::Base.class_eval do
      connection.instance_eval do
        create_table :test_objects, force: true do |t|
          t.string :first_name
          t.string :last_name
          t.string :email
          t.string :phone
          t.timestamps
        end
      end
    end
  end

  config.before do
    CleverEvents.configure do |events_config|
      events_config.publish_events = true
      events_config.sns_topic_arn = "arn:aws:sns:us-east-1:000000000000:my-test-topic"
    end
  end

  config.after do
    CleverEvents.configure do |events_config|
      events_config.publish_events = false
      events_config.sns_topic_arn = nil
    end
  end
end

require "dummy_app/init"
