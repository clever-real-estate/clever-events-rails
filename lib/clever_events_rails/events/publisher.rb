# frozen_string_literal: true

module Events
  module Publisher
    extend ActiveSupport::Concern
    include Events::Publisher::Publishable
    include Events::Adapters::SnsAdapter

    included do
      after_commit do
        publish_event! if publish_event?
      end

      def publish_event!
        Events::Publisher.publish_event!(event_name, self)
      end

      private

      def event_name
        "#{self.class.name}.#{event_type}"
      end
    end

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
        Events::Adapters::SnsAdapter
      end
    end
  end
end
