# frozen_string_literal: true

require "aws-sdk-sqs"
require "clever_events_rails/clever_events/adapters/aws_credentials"

module CleverEvents
  module Adapters
    module SqsAdapter
      class << self
        def receive_messages(queue_url: default_queue_url, max_messages: 1, wait_time_seconds: 0)
          raise "Invalid queue config" unless queue_url ||= default_queue_url

          response = sqs_client.receive_message(
            queue_url: queue_url,
            max_number_of_messages: max_messages,
            wait_time_seconds: wait_time_seconds
          )

          Rails.logger.info("Received #{response.messages.size} messages from SQS") if response
          response&.messages || []
        rescue StandardError => e
          handle_receive_error(e)
        end

        def delete_message(receipt_handle:, queue_url: default_queue_url)
          raise "Invalid queue config" unless queue_url ||= default_queue_url

          delete_message_from_sqs(receipt_handle, queue_url)
        rescue Aws::SQS::Errors::InvalidReceiptHandle => e
          handle_invalid_receipt_error(e)
        rescue StandardError => e
          handle_delete_error(e)
        end

        private

        def sqs_client
          Aws::SQS::Client.new(
            region: credentials.region,
            access_key_id: credentials.access_key_id,
            secret_access_key: credentials.secret_access_key
          )
        end

        def credentials
          @credentials ||= CleverEvents::Adapters::AwsCredentials.new
        end

        def default_queue_url
          CleverEvents.configuration.sqs_queue_url
        end

        def handle_receive_error(error)
          Rails.logger.error("Failed to receive messages from SQS: #{error.message}")
          raise CleverEvents::Error, error.message
        end

        def handle_invalid_receipt_error(error)
          Rails.logger.error("Failed to delete message from SQS: #{error.message}")
          false
        end

        def handle_delete_error(error)
          Rails.logger.error("Failed to delete message from SQS: #{error.message}")
          raise CleverEvents::Error, error.message
        end

        def delete_message_from_sqs(receipt_handle, queue_url)
          response = sqs_client.delete_message(
            queue_url: queue_url,
            receipt_handle: receipt_handle
          )
          Rails.logger.info("Deleted message from SQS") if response
          true
        end
      end
    end
  end
end
