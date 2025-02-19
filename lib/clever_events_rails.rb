# frozen_string_literal: true

require_relative "clever_events_rails/version"

module CleverEventsRails
  class Error < StandardError; end
  require "rails"
  require "clever_events_rails/clever_events"
  require "clever_events_rails/railtie"
end
