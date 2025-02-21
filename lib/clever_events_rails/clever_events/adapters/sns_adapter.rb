# frozen_string_literal: true

require "aws-sdk-sns"
require "clever_events_rails/clever_events/adapters/sns_adapter/credentials"

module CleverEvents
  module Adapters
    module SnsAdapter
      class << self
        def publish_event(event_name, entity, message_deduplication_id, topic_arn = default_topic_arn) # rubocop:disable Metrics/MethodLength
          raise "Invalid topic config" unless topic_arn ||= default_topic_arn

          sns_client.publish(
            topic_arn: topic_arn,
            message: Message.new(event_name, entity).build_message,
            message_structure: "json",
            subject: event_name,
            message_group_id: message_group_id(entity),
            message_deduplication_id: message_deduplication_id
          )
        rescue StandardError => e
          Rails.logger.error("Event publishing failed publishing to SNS: #{e.message}")
          raise e
        end

        private

        def sns_client
          Aws::SNS::Client.new(
            region: credentials.region,
            access_key_id: credentials.access_key_id,
            secret_access_key: credentials.secret_access_key
          )
        end

        def credentials
          @credentials ||= CleverEvents::Adapters::SnsAdapter::Credentials.new
        end

        def default_topic_arn
          CleverEvents.configuration.sns_topic_arn
        end

        def message_group_id(entity)
          "#{entity.class.name.underscore.downcase}.#{entity.id}"
        end
      end
    end
  end
end
