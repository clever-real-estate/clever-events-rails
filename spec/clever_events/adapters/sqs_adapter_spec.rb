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

  describe ".process_messages" do
    def test_message(id)
      Aws::SQS::Types::Message.new(
        message_id: "test-message-#{id}",
        receipt_handle: "test-receipt-handle-#{id}",
        body: "test message #{id}"
      )
    end

    def test_messages
      [test_message("1"), test_message("2")]
    end

    def large_test_batch
      (1..25).map { |i| test_message(i.to_s) }
    end

    let(:processor_class) { class_double(CleverEvents::Processor) }

    before do
      allow(sqs_client).to receive(:delete_message_batch).and_return(
        Aws::SQS::Types::DeleteMessageBatchResult.new(
          successful: [
            Aws::SQS::Types::DeleteMessageBatchResultEntry.new(id: "0"),
            Aws::SQS::Types::DeleteMessageBatchResultEntry.new(id: "1")
          ],
          failed: []
        )
      )
      allow(Rails.logger).to receive(:error)
      allow(Rails.logger).to receive(:info)
    end

    it "processes each message with the processor class" do
      allow(processor_class).to receive(:process)

      described_class.process_messages(test_messages, processor_class: processor_class)

      expect(processor_class).to have_received(:process).twice
    end

    it "deletes successfully processed messages using batch deletion" do
      allow(processor_class).to receive(:process)

      described_class.process_messages(test_messages, processor_class: processor_class)

      expect(sqs_client).to have_received(:delete_message_batch).with(
        queue_url: queue_url,
        entries: [
          { id: "0", receipt_handle: "test-receipt-handle-1" },
          { id: "1", receipt_handle: "test-receipt-handle-2" }
        ]
      )
    end

    it "continues processing remaining messages when one fails" do
      messages = test_messages
      allow(processor_class).to receive(:process).with(messages[0], queue_url: queue_url)
                                                 .and_raise(StandardError.new("Processing error"))
      allow(processor_class).to receive(:process).with(messages[1], queue_url: queue_url)

      described_class.process_messages(messages, processor_class: processor_class)

      expect(sqs_client).to have_received(:delete_message_batch).with(
        queue_url: queue_url,
        entries: [{ id: "0", receipt_handle: "test-receipt-handle-2" }]
      )
    end

    it "logs errors and continues processing other messages" do
      messages = test_messages
      error = StandardError.new("Processing error")
      allow(processor_class).to receive(:process).with(messages[0], queue_url: queue_url)
                                                 .and_raise(error)
      allow(processor_class).to receive(:process).with(messages[1], queue_url: queue_url)

      described_class.process_messages(messages, processor_class: processor_class)

      expect(Rails.logger).to have_received(:error).with("Failed to process message: Processing error")
    end

    it "does not call delete_message_batch if no messages were successfully processed" do
      allow(processor_class).to receive(:process).and_raise(StandardError.new("Processing error"))

      described_class.process_messages(test_messages, processor_class: processor_class)

      expect(sqs_client).not_to have_received(:delete_message_batch)
    end

    context "with custom queue URL" do
      let(:custom_queue_url) { "https://sqs.custom.amazonaws.com/123456789012/custom-queue" }

      before do
        allow(processor_class).to receive(:process)
      end

      it "passes the custom queue URL to the processor" do
        described_class.process_messages(test_messages, processor_class: processor_class, queue_url: custom_queue_url)

        expect(processor_class).to have_received(:process).twice
      end

      it "passes the custom queue URL to the batch deletion" do
        described_class.process_messages(test_messages, processor_class: processor_class, queue_url: custom_queue_url)

        expect(sqs_client).to have_received(:delete_message_batch).with(
          queue_url: custom_queue_url,
          entries: anything
        )
      end
    end

    it "processes messages in batches of 10" do
      allow(processor_class).to receive(:process)

      described_class.process_messages(large_test_batch, processor_class: processor_class)

      expect(sqs_client).to have_received(:delete_message_batch).exactly(3).times
    end

    context "when queue_url is not set" do
      before do
        allow(CleverEvents.configuration).to receive(:sqs_queue_url).and_return(nil)
      end

      it "raises an error" do
        expect do
          described_class.process_messages(test_messages)
        end.to raise_error(CleverEvents::Error, "Invalid queue config")
      end
    end
  end

  describe ".delete_messages" do
    def test_message(id)
      Aws::SQS::Types::Message.new(
        message_id: "test-message-#{id}",
        receipt_handle: "test-receipt-handle-#{id}",
        body: "test message #{id}"
      )
    end

    def test_messages
      [test_message("1"), test_message("2")]
    end

    def delete_batch_response
      Aws::SQS::Types::DeleteMessageBatchResult.new(
        successful: [
          Aws::SQS::Types::DeleteMessageBatchResultEntry.new(id: "0"),
          Aws::SQS::Types::DeleteMessageBatchResultEntry.new(id: "1")
        ],
        failed: []
      )
    end

    before do
      allow(sqs_client).to receive(:delete_message_batch).and_return(delete_batch_response)
      allow(Rails.logger).to receive(:info)
      allow(Rails.logger).to receive(:error)
    end

    it "sends delete_message_batch request with correct parameters" do
      described_class.delete_messages(test_messages)

      expect(sqs_client).to have_received(:delete_message_batch).with(
        queue_url: queue_url,
        entries: [
          { id: "0", receipt_handle: "test-receipt-handle-1" },
          { id: "1", receipt_handle: "test-receipt-handle-2" }
        ]
      )
    end

    it "logs success message when deletion succeeds" do
      described_class.delete_messages(test_messages)

      expect(Rails.logger).to have_received(:info).with("Deleted 2 messages from SQS")
    end

    it "allows custom queue URL to be specified" do
      custom_queue_url = "https://sqs.custom.amazonaws.com/123456789012/custom-queue"

      described_class.delete_messages(test_messages, queue_url: custom_queue_url)

      expect(sqs_client).to have_received(:delete_message_batch).with(
        queue_url: custom_queue_url,
        entries: anything
      )
    end

    it "processes messages in batches of 10" do
      large_batch = (1..25).map { |i| test_message(i.to_s) }

      described_class.delete_messages(large_batch)

      expect(sqs_client).to have_received(:delete_message_batch).exactly(3).times
    end

    it "handles empty message list" do
      described_class.delete_messages([])
      expect(sqs_client).not_to have_received(:delete_message_batch)
    end

    it "handles nil response without logging failure messages" do
      allow(sqs_client).to receive(:delete_message_batch).and_return(nil)

      described_class.delete_messages(test_messages)

      expect(Rails.logger).not_to have_received(:error).with(/Failed to delete message/)
    end

    it "handles nil response without logging success messages" do
      allow(sqs_client).to receive(:delete_message_batch).and_return(nil)

      described_class.delete_messages(test_messages)

      expect(Rails.logger).not_to have_received(:info).with(/Deleted \d+ messages from SQS/)
    end

    it "handles response with nil failed entries without logging failures" do
      response_with_nil_failed = Aws::SQS::Types::DeleteMessageBatchResult.new(
        successful: [Aws::SQS::Types::DeleteMessageBatchResultEntry.new(id: "0")],
        failed: nil
      )
      allow(sqs_client).to receive(:delete_message_batch).and_return(response_with_nil_failed)

      described_class.delete_messages(test_messages)

      expect(Rails.logger).not_to have_received(:error).with(/Failed to delete message/)
    end

    context "with deletion failures" do
      before do
        failure_response = Aws::SQS::Types::DeleteMessageBatchResult.new(
          successful: [Aws::SQS::Types::DeleteMessageBatchResultEntry.new(id: "0")],
          failed: [
            Aws::SQS::Types::BatchResultErrorEntry.new(
              id: "1",
              code: "InternalError",
              message: "Internal Error"
            )
          ]
        )
        allow(sqs_client).to receive(:delete_message_batch).and_return(failure_response)
      end

      it "logs failures" do
        described_class.delete_messages(test_messages)

        expect(Rails.logger).to have_received(:error)
          .with("Failed to delete message 1: InternalError - Internal Error")
      end
    end

    context "with batch deletion error" do
      before do
        allow(sqs_client).to receive(:delete_message_batch)
          .and_raise(Aws::SQS::Errors::ServiceError.new(nil, "SQS Batch Delete Error"))
      end

      it "logs the error" do
        allow(described_class).to receive(:raise)

        described_class.delete_messages(test_messages)

        expect(Rails.logger).to have_received(:error)
          .with("Failed to batch delete messages from SQS: SQS Batch Delete Error")
      end

      it "raises a CleverEvents error" do
        expect do
          described_class.delete_messages(test_messages)
        end.to raise_error(CleverEvents::Error, "SQS Batch Delete Error")
      end
    end
  end

  describe ".send_message" do
    def message_body
      "test message body"
    end

    def message_attributes
      { "attribute" => { data_type: "String", string_value: "value" } }
    end

    def message_id
      "test-message-id"
    end

    def send_message_response
      instance_double(Aws::SQS::Types::SendMessageResult, message_id: message_id)
    end

    before do
      allow(sqs_client).to receive(:send_message).and_return(send_message_response)
      allow(Rails.logger).to receive(:info)
      allow(Rails.logger).to receive(:error)
    end

    it "sends message to SQS with correct parameters" do
      described_class.send_message(
        queue_url: queue_url,
        message_body: message_body,
        message_attributes: message_attributes
      )

      expect(sqs_client).to have_received(:send_message).with(
        queue_url: queue_url,
        message_body: message_body,
        message_attributes: message_attributes
      )
    end

    it "logs the message ID after successful send" do
      described_class.send_message(
        queue_url: queue_url,
        message_body: message_body,
        message_attributes: message_attributes
      )

      expect(Rails.logger).to have_received(:info).with("Sent message to SQS: #{message_id}")
    end

    it "returns true when message is sent successfully" do
      result = described_class.send_message(
        queue_url: queue_url,
        message_body: message_body,
        message_attributes: message_attributes
      )

      expect(result).to be true
    end

    it "handles nil response without logging message ID" do
      allow(sqs_client).to receive(:send_message).and_return(nil)

      described_class.send_message(
        queue_url: queue_url,
        message_body: message_body,
        message_attributes: message_attributes
      )

      expect(Rails.logger).not_to have_received(:info).with(/Sent message to SQS:/)
    end

    describe "when the queue_url is not set" do
      it "raises an error" do
        allow(CleverEvents.configuration).to receive(:sqs_queue_url).and_return(nil)

        expect do
          described_class.send_message(
            queue_url: nil,
            message_body: message_body,
            message_attributes: message_attributes
          )
        end.to raise_error(CleverEvents::Error, "Invalid queue config")
      end
    end

    context "when SQS returns an error" do
      let(:error) { Aws::SQS::Errors::ServiceError.new(nil, "SQS error") }

      before do
        allow(sqs_client).to receive(:send_message).and_raise(error)
      end

      it "logs the error message" do
        allow(error).to receive(:backtrace).and_return(nil)

        suppress(StandardError) do
          described_class.send_message(
            queue_url: queue_url,
            message_body: message_body,
            message_attributes: message_attributes
          )
        end

        expect(Rails.logger).to have_received(:error).with("Failed to send message to SQS: SQS error")
      end

      it "re-raises the error" do
        expect do
          described_class.send_message(
            queue_url: queue_url,
            message_body: message_body,
            message_attributes: message_attributes
          )
        end.to raise_error(Aws::SQS::Errors::ServiceError)
      end
    end
  end
end
