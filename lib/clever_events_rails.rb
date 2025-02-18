# frozen_string_literal: true

require_relative "clever_events_rails/version"

module CleverEventsRails
  class Error < StandardError; end
  require "rails"
  require "clever_events_rails/clever_events/message"
  require "clever_events_rails/clever_events/adapters"
  require "clever_events_rails/clever_events/publishable"
  require "clever_events_rails/clever_events/publisher"
  require "clever_events_rails/railtie"
end
