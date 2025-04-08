# frozen_string_literal: true

module CleverEvents
  module Publisher
    extend ActiveSupport::Concern

    class << self
      def publish_event!(event_name, entity, message_deduplication_id, arn = nil)
        Rails.logger.warn("Event publishing disabled, check env") and return unless can_publish?

        event_adapter.publish_event(event_name, entity, message_deduplication_id, arn)
      rescue StandardError => e
        Rails.logger.error("Event publishing failed: #{e.message}")
        raise Error, e.message
      end

      private

      def can_publish?
        CleverEvents.configuration.publish_events
      end

      def event_adapter
        CleverEvents.configuration.events_adapter
      end
    end
  end
end
