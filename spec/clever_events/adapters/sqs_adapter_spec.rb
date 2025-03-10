# frozen_string_literal: true

require "spec_helper"

RSpec.describe CleverEvents::Adapters::SqsAdapter, type: :model do
  let(:sqs_client) { Aws::SQS::Client.new(stub_responses: true) }
  let(:queue_url) { "https://sqs.test.amazonaws.com/123456789012/test-queue" }
  let(:receipt_handle) { "test-receipt-handle" }

  before do
    allow(Aws::SQS::Client).to receive(:new).and_return(sqs_client)
    allow(CleverEvents.configuration).to receive(:sqs_queue_url).and_return(queue_url)
  end

  describe ".receive_messages" do
    let(:messages) do
      [
        Aws::SQS::Types::Message.new(
          message_id: "test-message-1",
          receipt_handle: receipt_handle,
          body: "test message 1"
        ),
        Aws::SQS::Types::Message.new(
          message_id: "test-message-2",
          receipt_handle: "test-receipt-handle-2",
          body: "test message 2"
        )
      ]
    end

    before do
      allow(sqs_client).to receive(:receive_message).and_return(
        Aws::SQS::Types::ReceiveMessageResult.new(messages: messages)
      )
    end

    it "calls receive_message with correct parameters" do
      described_class.receive_messages(max_messages: 2)

      expect(sqs_client).to have_received(:receive_message).with(
        queue_url: queue_url,
        max_number_of_messages: 2,
        wait_time_seconds: 0
      )
    end

    it "returns received messages" do
      result = described_class.receive_messages(max_messages: 2)
      expect(result).to eq(messages)
    end

    it "calls receive_message when handling empty response" do
      allow(sqs_client).to receive(:receive_message).and_return(
        Aws::SQS::Types::ReceiveMessageResult.new(messages: [])
      )

      described_class.receive_messages
      expect(sqs_client).to have_received(:receive_message)
    end

    it "returns empty array for empty response" do
      allow(sqs_client).to receive(:receive_message).and_return(
        Aws::SQS::Types::ReceiveMessageResult.new(messages: [])
      )

      result = described_class.receive_messages
      expect(result).to eq([])
    end

    it "allows customizing wait time" do
      described_class.receive_messages(wait_time_seconds: 20)

      expect(sqs_client).to have_received(:receive_message).with(
        queue_url: queue_url,
        max_number_of_messages: 1,
        wait_time_seconds: 20
      )
    end

    describe "when the queue_url is not set" do
      it "raises an error" do
        allow(CleverEvents.configuration).to receive(:sqs_queue_url).and_return(nil)

        expect do
          described_class.receive_messages
        end.to raise_error(CleverEvents::Error, "Invalid queue config")
      end
    end

    describe "when SQS returns an error" do
      before do
        allow(sqs_client).to receive(:receive_message).and_raise(
          Aws::SQS::Errors::ServiceError.new(nil, "SQS error")
        )
      end

      it "raises a CleverEvents error" do
        expect do
          described_class.receive_messages
        end.to raise_error(CleverEvents::Error, "SQS error")
      end
    end
  end

  describe ".delete_message" do
    before do
      allow(sqs_client).to receive(:delete_message)
    end

    it "deletes a message from the SQS queue" do
      allow(sqs_client).to receive(:delete_message).and_return({})

      described_class.delete_message(receipt_handle: receipt_handle)

      expect(sqs_client).to have_received(:delete_message).with(
        queue_url: queue_url,
        receipt_handle: receipt_handle
      )
    end

    it "returns true when message is deleted successfully" do
      allow(sqs_client).to receive(:delete_message).and_return({})

      result = described_class.delete_message(receipt_handle: receipt_handle)
      expect(result).to be true
    end

    it "calls delete_message when handling nil response" do
      allow(sqs_client).to receive(:delete_message).and_return(nil)
      described_class.delete_message(receipt_handle: receipt_handle)
      expect(sqs_client).to have_received(:delete_message)
    end

    it "returns true for nil response" do
      allow(sqs_client).to receive(:delete_message).and_return(nil)
      result = described_class.delete_message(receipt_handle: receipt_handle)
      expect(result).to be true
    end

    describe "when the queue_url is not set" do
      it "raises an error" do
        allow(CleverEvents.configuration).to receive(:sqs_queue_url).and_return(nil)

        expect do
          described_class.delete_message(receipt_handle: receipt_handle)
        end.to raise_error(CleverEvents::Error, "Invalid queue config")
      end
    end

    describe "when the receipt handle is invalid" do
      before do
        allow(sqs_client).to receive(:delete_message).and_raise(
          Aws::SQS::Errors::InvalidReceiptHandle.new(nil, "Invalid receipt handle")
        )
      end

      it "returns false" do
        result = described_class.delete_message(receipt_handle: receipt_handle)
        expect(result).to be false
      end
    end

    describe "when SQS returns an error" do
      before do
        allow(sqs_client).to receive(:delete_message).and_raise(
          Aws::SQS::Errors::ServiceError.new(nil, "SQS error")
        )
      end

      it "raises a CleverEvents error" do
        expect do
          described_class.delete_message(receipt_handle: receipt_handle)
        end.to raise_error(CleverEvents::Error, "SQS error")
      end
    end
  end
end
