# frozen_string_literal: true

module DummyApp
  class MessageProcessor < CleverEvents::Processor
    def self.process(message)
      new(message).process
    end

    def process
      sns_notification = JSON.parse(message.body)
      message_body = JSON.parse(sns_notification["Message"])

      # Simulate processing
      case message_body["event_name"]
      when "TestEvent"
        # Successful processing
        true
      else
        raise "Unknown event type"
      end
    rescue JSON::ParserError => e
      Rails.logger.error("Failed to parse message body as JSON: #{e.message}")
      raise e
    end
  end
end
