# frozen_string_literal: true

class SqsMessageProcessorJob < ApplicationJob
  queue_as :default

  def perform
    messages = CleverEvents::Subscriber.receive_messages

    messages.each do |message|
      begin
        process_message(message)
        CleverEvents::Adapters::SqsAdapter.delete_message(
          receipt_handle: message.receipt_handle
        )
      rescue StandardError => e
        Rails.logger.error("Failed to process message: #{e.class} - #{e.message}")
      end
    end
  end

  private

  def process_message(message)
    data = JSON.parse(message.body)
    Rails.logger.info("Processing message: #{data}")
  end
end
