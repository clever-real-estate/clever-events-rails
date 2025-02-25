# frozen_string_literal: true

module CleverEvents
  class Error < StandardError; end

  require "clever_events_rails/clever_events/message"
  require "clever_events_rails/clever_events/adapters"
  require "clever_events_rails/clever_events/publishable"
  require "clever_events_rails/clever_events/publisher"
  require "clever_events_rails/clever_events/configuration"

  class << self
    def configuration
      @configuration ||= CleverEvents::Configuration.new
    end

    def configure
      yield(configuration)
    end
  end
end
