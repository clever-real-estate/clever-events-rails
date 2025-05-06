# frozen_string_literal: true

require "aws-sdk-sqs"
require "clever_events_rails/clever_events/adapters/aws_credentials"
require "clever_events_rails/clever_events/processor"

module CleverEvents
  module Adapters
    module SqsAdapter # rubocop:disable Metrics/ModuleLength
      class << self # rubocop:disable Metrics/ClassLength
        def receive_messages(queue_url: default_queue_url, max_messages: 1, wait_time_seconds: 0)
          validate_queue_url(queue_url)

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

        def process_messages(messages, processor_class: CleverEvents::Processor, queue_url: default_queue_url)
          validate_queue_url(queue_url)
          processed_messages = []

          messages.each do |message|
            processor_class.process(message, queue_url: queue_url)
            processed_messages << message
          rescue StandardError => e
            Rails.logger.error("Failed to process message: #{e.message}")
            next
          end

          delete_messages(processed_messages, queue_url: queue_url) if processed_messages.any?
        end

        def delete_messages(messages, queue_url: default_queue_url)
          validate_queue_url(queue_url)
          return if messages.empty?

          messages.each_slice(10) do |batch|
            entries = batch.map.with_index do |message, index|
              { id: index.to_s, receipt_handle: message.receipt_handle }
            end

            delete_message_batch(entries: entries, queue_url: queue_url)
          end
        end

        def delete_message(receipt_handle:, queue_url: default_queue_url)
          validate_queue_url(queue_url)
          delete_message_from_sqs(receipt_handle, queue_url)
        rescue Aws::SQS::Errors::InvalidReceiptHandle => e
          handle_invalid_receipt_error(e)
        rescue StandardError => e
          handle_delete_error(e)
        end

        def send_message(queue_url:, message_body:, message_attributes:)
          validate_queue_url(queue_url)
          response = send_message_to_sqs(queue_url, message_body, message_attributes)
          Rails.logger.info("Sent message to SQS: #{response.message_id}") if response
          true
        rescue StandardError => e
          log_send_error(e)
          raise e
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

        def validate_queue_url(queue_url)
          queue_url ||= default_queue_url

          raise CleverEvents::Error, "Invalid queue config" unless queue_url
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

        def send_message_to_sqs(queue_url, message_body, message_attributes)
          sqs_client.send_message(
            queue_url: queue_url,
            message_body: message_body,
            message_attributes: message_attributes
          )
        end

        def log_send_error(error)
          Rails.logger.error("Failed to send message to SQS: #{error.message}")
        end

        def delete_message_batch(entries:, queue_url:)
          response = sqs_client.delete_message_batch(
            queue_url: queue_url,
            entries: entries
          )

          log_batch_delete_failures(response.failed) if response&.failed && response.failed.any?

          Rails.logger.info("Deleted #{entries.size} messages from SQS") if response
          true
        rescue StandardError => e
          Rails.logger.error("Failed to batch delete messages from SQS: #{e.message}")
          raise CleverEvents::Error, e.message
        end

        def log_batch_delete_failures(failed_entries)
          failed_entries.each do |failed|
            Rails.logger.error(
              "Failed to delete message #{failed.id}: #{failed.code} - #{failed.message}"
            )
          end
        end
      end
    end
  end
end
