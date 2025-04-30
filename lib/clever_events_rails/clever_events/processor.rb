# frozen_string_literal: true

module CleverEvents
  class Processor
    MAX_RETRIES = 3

    def self.process(message, queue_url: nil)
      new(message, queue_url: queue_url).process
    end

    def initialize(message, queue_url: nil)
      @message = message
      @queue_url = queue_url
      @retry_count = message.attributes["ApproximateReceiveCount"].to_i
    end

    def process
      process_message
    rescue StandardError => e
      raise e if retry_count < MAX_RETRIES

      handle_processing_error(e)
    end

    private

    attr_reader :message, :retry_count, :queue_url

    def process_message
      raise NotImplementedError, "#{self.class.name} must implement process_message method"
    end

    def handle_processing_error(error)
      log_error(error)

      if dlq_configured?
        attempt_move_to_dlq(error)
      else
        log_dlq_not_configured
      end
    end

    def log_error(error)
      Rails.logger.error("Failed to process message: #{error.message}")
      Rails.logger.error(error.backtrace.join("\n")) if error.backtrace
    end

    def attempt_move_to_dlq(error)
      move_to_dlq(error)
    rescue StandardError => e
      Rails.logger.error("Failed to move message to DLQ: #{e.message}")
      raise e
    end

    def log_dlq_not_configured
      Rails.logger.warn("Message #{message.message_id} exceeded max retries but DLQ not configured")
    end

    def move_to_dlq(error)
      CleverEvents::Adapters::SqsAdapter.send_message(
        queue_url: CleverEvents.configuration.sqs_dlq_url,
        message_body: message.body,
        message_attributes: dlq_message_attributes(error)
      )
      log_dlq_success
    end

    def dlq_message_attributes(error)
      message.message_attributes.merge(
        "original_queue" => { data_type: "String", string_value: queue_url },
        "failure_reason" => { data_type: "String", string_value: error.message },
        "retry_count" => { data_type: "Number", string_value: retry_count.to_s },
        "failed_at" => { data_type: "String", string_value: Time.current.iso8601 }
      )
    end

    def log_dlq_success
      Rails.logger.info("Moved failed message to DLQ: #{message.message_id}")
    end

    def dlq_configured?
      CleverEvents.configuration.sqs_dlq_url.present?
    end
  end
end
