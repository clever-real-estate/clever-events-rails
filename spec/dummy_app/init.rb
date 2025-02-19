# frozen_string_literal: true

ENV["RAILS_ENV"] ||= "test"

# require rails piece by piece
%w[
  active_record/railtie
  action_controller/railtie
].each do |railtie|
  require railtie
rescue LoadError # rubocop:disable Lint/SuppressedException
end

require "clever_events_rails"
require "securerandom"

module DummyApp
  class Application < Rails::Application
    # Basic Engine
    config.root = File.join __FILE__, ".."
    config.cache_store = :memory_store
    config.assets.enabled = false if Rails.version < "7.0.0"
    config.secret_token = "012345678901234567890123456789"
    config.active_support.test_order = :random
    # Mimic Test Environment Config.
    config.whiny_nils = true
    config.consider_all_requests_local = true
    config.action_dispatch.show_exceptions = false
    config.action_controller.allow_forgery_protection = false
    config.active_support.deprecation = :stderr
    config.allow_concurrency = true
    config.cache_classes = true
    config.dependency_loading = true
    config.preload_frameworks = true
    config.eager_load = true
  end
end

DummyApp::Application.initialize!
