# frozen_string_literal: true

module CleverEvents
  module Subscriber
    extend ActiveSupport::Concern
    include CleverEvents::Adapters::SqsAdapter

    class << self
      def receive_messages
        message_processor_adapter.receive_messages(max_messages: default_message_batch_size)
      rescue StandardError => e
        Rails.logger.error("Failed to subscribe to events: #{e.message}")
        raise CleverEvents::Error, e.message
      end

      private

      def message_processor_adapter
        CleverEvents.configuration.message_processor_adapter
      end

      def default_message_batch_size
        CleverEvents.configuration.default_message_batch_size
      end
    end
  end
end
