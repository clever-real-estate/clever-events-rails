# frozen_string_literal: true

require "pry"
require "factory_bot"
require "temping"

require "clever_events_rails"

spec = Gem::Specification.find_by_name("clever_events_rails")
gem_root = spec.gem_dir

helpers = Dir[File.join(gem_root, "spec", "support", "**", "*.rb")]
helpers -= Dir[File.join(gem_root, "spec", "support", "test_models", "**", "*.rb")]
helpers.each { |f| require f }

Temping.class_eval do
  # Force temping not to use its own connection, but use the Rails connection
  def self.connect
    ActiveRecord::Base.establish_connection
  end
end

require "dummy_app/init"

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
    Temping.create(:test_object) do
      with_columns do |t|
        t.string :first_name
        t.string :last_name
      end

      include Events::Publisher::Publishable

      publishable_attrs :first_name, :last_name, :email, :phone
      publishable_actions :created, :updated, :destroyed

      def publish_event!(_event_name)
        true
      end
    end
  end

  config.after do
    Temping.teardown
  end
end
