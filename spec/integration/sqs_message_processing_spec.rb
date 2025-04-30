# frozen_string_literal: true

require "spec_helper"

module CleverEventsRails
  RSpec.describe "SQS Message Processing Integration Test" do
    let(:sqs_client) { Aws::SQS::Client.new(stub_responses: true) }
    let(:queue_url) { "https://sqs.test.amazonaws.com/123456789012/test-queue" }
    let(:receipt_handle) { "test-receipt-handle" }
    let(:logger) { Rails.logger }

    before do
      allow(Aws::SQS::Client).to receive(:new).and_return(sqs_client)
      allow(CleverEvents.configuration).to receive(:sqs_queue_url).and_return(queue_url)
      allow(logger).to receive(:info)
      allow(logger).to receive(:error)
    end

    describe "processing messages from SQS" do
      let(:messages) do
        [
          Aws::SQS::Types::Message.new(
            message_id: "test-message-1",
            receipt_handle: receipt_handle,
            body: { event_type: "test_event", data: "test data" }.to_json
          )
        ]
      end

      before do
        allow(sqs_client).to receive_messages(
          receive_message: Aws::SQS::Types::ReceiveMessageResult.new(messages: messages),
          delete_message: {}
        )
        allow(CleverEvents.configuration).to receive(:default_message_batch_size).and_return(10)
      end

      it "receives messages from SQS" do
        SqsMessageProcessorJob.perform_now

        expect(sqs_client).to have_received(:receive_message).with(
          queue_url: queue_url,
          max_number_of_messages: 10,
          wait_time_seconds: 0
        )
      end

      it "deletes messages after processing" do
        SqsMessageProcessorJob.perform_now

        expect(sqs_client).to have_received(:delete_message).with(
          queue_url: queue_url,
          receipt_handle: receipt_handle
        )
      end

      it "logs the processed message" do
        SqsMessageProcessorJob.perform_now

        expect(logger).to have_received(:info).with(
          "Processing message: {\"event_type\"=>\"test_event\", \"data\"=>\"test data\"}"
        )
      end

      context "when message processing fails" do
        before do
          allow(JSON).to receive(:parse).and_raise(StandardError, "Processing error")
        end

        it "logs the error but does not raise it" do
          SqsMessageProcessorJob.perform_now

          expect(logger).to have_received(:error).with(
            "Failed to process message: StandardError - Processing error"
          )
        end
      end

      context "when the queue URL is not configured" do
        before do
          allow(CleverEvents.configuration).to receive(:sqs_queue_url).and_return(nil)
        end

        it "raises a CleverEvents error" do
          expect { SqsMessageProcessorJob.perform_now }
            .to raise_error(CleverEvents::Error, "Invalid queue config")
        end
      end

      context "when receiving messages" do
        it "logs the number of messages received" do
          CleverEvents::Adapters::SqsAdapter.receive_messages

          expect(logger).to have_received(:info).with(
            "Received 1 messages from SQS"
          )
        end

        it "returns empty array for nil response" do
          allow(sqs_client).to receive(:receive_message).and_return(nil)
          result = CleverEvents::Adapters::SqsAdapter.receive_messages
          expect(result).to eq([])
        end

        it "does not log info for nil response" do
          allow(sqs_client).to receive(:receive_message).and_return(nil)
          CleverEvents::Adapters::SqsAdapter.receive_messages
          expect(logger).not_to have_received(:info)
        end
      end
    end

    describe "configuration" do
      it "uses SQS as the default message processor adapter" do
        expect(CleverEvents.configuration.message_processor_adapter).to eq(CleverEvents::Adapters::SqsAdapter)
      end

      it "falls back to SQS adapter when invalid adapter is configured" do
        CleverEvents.configuration.message_processor_adapter = :invalid
        expect(CleverEvents.configuration.message_processor_adapter).to eq(CleverEvents::Adapters::SqsAdapter)
      end
    end
  end
end
