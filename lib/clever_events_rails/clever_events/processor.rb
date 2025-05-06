# frozen_string_literal: true

module CleverEvents
  class Processor
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
      log_error(e)
      raise e # Re-raise the error to let SQS handle retries and DLQ routing
    end

    private

    attr_reader :message, :retry_count, :queue_url

    def process_message
      raise NotImplementedError, "#{self.class.name} must implement process_message method"
    end

    def log_error(error)
      Rails.logger.error("Failed to process message: #{error.message}")
      Rails.logger.error(error.backtrace.join("\n")) if error.backtrace
      Rails.logger.info("Message will be retried by SQS (current retry count: #{retry_count})")
    end
  end
end
