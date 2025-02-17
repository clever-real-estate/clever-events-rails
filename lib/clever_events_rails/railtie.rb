# frozen_string_literal: true

require "rails/railtie"
module CleverEventsRails
  class Railtie < ::Rails::Railtie
    config.clever_events_rails = ActiveSupport::OrderedOptions.new
    config.clever_events_rails.publish_events = false

    config.before_initialize do |_app|
      require "active_support/concern"
    end
  end
end
