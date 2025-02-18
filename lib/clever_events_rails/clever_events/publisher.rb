# frozen_string_literal: true

module CleverEvents
  module Publisher
    extend ActiveSupport::Concern
    include CleverEvents::Adapters::SnsAdapter

    class << self
      def publish_event!(event_name, entity)
        Rails.logger.warn("Event publishing disabled, check env") and return unless can_publish?

        event_adapter.publish_event(event_name, entity)
      rescue StandardError => e
        Rails.logger.error("Event publishing failed: #{e.message}")
        raise e
      end

      private

      def can_publish?
        !!Rails.configuration.clever_events_rails.publish_events
      end

      def event_adapter
        CleverEvents::Adapters::SnsAdapter
      end
    end
  end
end
