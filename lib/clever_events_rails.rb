# frozen_string_literal: true

require_relative "clever_events_rails/version"

module CleverEventsRails
  class Error < StandardError; end
  require "rails"
  require "clever_events_rails/events/message"
  require "clever_events_rails/events/adapters"
  require "clever_events_rails/events/publisher/publishable"
  require "clever_events_rails/events/publisher"
  require "clever_events_rails/railtie"
end
