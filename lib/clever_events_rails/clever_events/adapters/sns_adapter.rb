# frozen_string_literal: true

require "aws-sdk-sns"
require "clever_events_rails/clever_events/adapters/aws_credentials"

module CleverEvents
  module Adapters
    class SnsAdapter
      class << self
        def publish_event(event_name, entity, message_deduplication_id, topic_arn = default_topic_arn)
          raise CleverEvents::Error, "Invalid topic config" unless topic_arn ||= default_topic_arn

          adapter = new(event_name, entity, message_deduplication_id, topic_arn)

          adapter.publish_event
        end

        private

        def default_topic_arn
          CleverEvents.configuration.sns_topic_arn
        end
      end

      def initialize(event_name, entity, message_deduplication_id, topic_arn)
        @event_name = event_name
        @entity = entity
        @message_deduplication_id = message_deduplication_id
        @topic_arn = topic_arn
      end

      def publish_event
        response = sns_client.publish(sns_request_options)

        Rails.logger.info("Event published to SNS message_id: #{response.message_id}") if response
      rescue StandardError => e
        Rails.logger.error("Event publishing failed publishing to SNS: #{e.message}")
        raise CleverEvents::Error, e.message
      end

      private

      attr_reader :event_name, :entity, :message_deduplication_id, :topic_arn

      def sns_request_options
        {
          topic_arn: topic_arn,
          message: message.build_message,
          subject: event_name,
          message_attributes: message.message_attributes
        }.tap do |options|
          options.merge!(fifo_options) if CleverEvents.configuration.fifo_topic?
        end
      end

      def sns_client
        @sns_client ||= Aws::SNS::Client.new(
          region: credentials.region,
          access_key_id: credentials.access_key_id,
          secret_access_key: credentials.secret_access_key
        )
      end

      def credentials
        @credentials ||= CleverEvents::Adapters::AwsCredentials.new
      end

      def message
        @message ||= Message.new(event_name, entity)
      end

      def message_group_id(entity)
        "#{entity.class.name.underscore.downcase}.#{entity.id}"
      end

      def fifo_options
        {
          message_deduplication_id: message_deduplication_id,
          message_group_id: message_group_id(entity)
        }
      end
    end
  end
end
