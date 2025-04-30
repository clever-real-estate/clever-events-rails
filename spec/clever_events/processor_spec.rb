# frozen_string_literal: true

require "spec_helper"

class DummyProcessor < CleverEvents::Processor
  def process_message
    true
  end
end

RSpec.describe CleverEvents::Processor do
  let(:retry_count) { 1 }
  let(:queue_url) { "test-queue-url" }
  let(:message) do
    instance_double(
      Aws::SQS::Types::Message,
      body: "test body",
      message_id: "test-message-id",
      message_attributes: {},
      attributes: { "ApproximateReceiveCount" => retry_count.to_s }
    )
  end
  let(:processor) { DummyProcessor.new(message, queue_url: queue_url) }
  let(:error) { StandardError.new("test error") }

  describe ".process" do
    it "creates a new instance with queue_url" do
      allow(described_class).to receive(:new).with(message, queue_url: queue_url).and_return(processor)

      DummyProcessor.process(message, queue_url: queue_url)
      expect(described_class).to have_received(:new).with(message, queue_url: queue_url)
    end

    it "calls process on the instance" do
      allow(described_class).to receive(:new).with(message, queue_url: queue_url).and_return(processor)
      allow(processor).to receive(:process)

      DummyProcessor.process(message, queue_url: queue_url)
      expect(processor).to have_received(:process)
    end
  end

  describe "#process" do
    it "raises NotImplementedError" do
      expect { described_class.process(message) }.to raise_error(NotImplementedError)
    end
  end

  describe "error handling" do
    before do
      allow(Rails.logger).to receive(:error)
      allow(Rails.logger).to receive(:warn)
      allow(Rails.logger).to receive(:info)
    end

    context "when retry count is below max retries" do
      before { allow(processor).to receive(:process_message).and_raise(error) }

      let(:retry_count) { 1 }

      it "re-raises the error for SQS to handle retry" do
        expect { processor.process }.to raise_error(error)
      end
    end

    context "when retry count exceeds max retries" do
      let(:retry_count) { 4 }

      context "when DLQ is configured" do
        before do
          allow(CleverEvents.configuration).to receive(:sqs_dlq_url).and_return("dlq-url")
          allow(CleverEvents::Adapters::SqsAdapter).to receive(:send_message).and_return(true)
        end

        it "moves message to DLQ" do
          allow(processor).to receive(:process).and_raise(error)

          suppress(StandardError) do
            processor.process
            expect(CleverEvents::Adapters::SqsAdapter).to have_received(:send_message).with(
              queue_url: "dlq-url",
              message_body: message.body,
              message_attributes: hash_including(
                "original_queue" => { data_type: "String", string_value: queue_url },
                "failure_reason" => { data_type: "String", string_value: error.message },
                "retry_count" => { data_type: "Number", string_value: retry_count.to_s },
                "failed_at" => { data_type: "String", string_value: Time.current.iso8601 }
              )
            )
          end
        end

        it "logs success after moving to DLQ" do
          allow(processor).to receive(:process).and_raise(error)

          suppress(StandardError) do
            processor.process
            expect(Rails.logger).to have_received(:info).with("Moved failed message to DLQ: #{message.message_id}")
          end
        end

        context "when DLQ send fails" do
          before do
            allow(CleverEvents.configuration).to receive(:sqs_dlq_url).and_return("dlq-url")
            allow(processor).to receive(:process_message).and_raise(error)

            # Setup DLQ error and SQS adapter in the before block
            dlq_error = StandardError.new("DLQ error")
            allow(CleverEvents::Adapters::SqsAdapter).to receive(:send_message).and_raise(dlq_error)
          end

          it "raises the DLQ error instead of the original error" do
            # Use local variable for consistency with before block
            dlq_error = StandardError.new("DLQ error")
            allow(CleverEvents::Adapters::SqsAdapter).to receive(:send_message).and_raise(dlq_error)

            expect { processor.process }.to raise_error(dlq_error)
          end

          it "logs the DLQ error" do
            allow(Rails.logger).to receive(:error)
            suppress(StandardError) do
              processor.process
              expect(Rails.logger).to have_received(:error).with(/Failed to move message to DLQ: DLQ error/)
            end
          end
        end
      end

      context "when DLQ is not configured" do
        before do
          allow(CleverEvents.configuration).to receive(:sqs_dlq_url).and_return(nil)
        end

        it "logs a warning" do
          allow(processor).to receive(:process).and_raise(error)

          suppress(StandardError) do
            processor.process
            expect(Rails.logger).to have_received(:warn).with(
              "Message #{message.message_id} exceeded max retries but DLQ not configured"
            )
          end
        end
      end
    end
  end

  describe "#log_error" do
    before do
      allow(Rails.logger).to receive(:error)
    end

    it "logs the error message" do
      processor.send(:log_error, error)

      expect(Rails.logger).to have_received(:error).with("Failed to process message: test error")
    end

    it "logs the error backtrace" do
      allow(error).to receive(:backtrace).and_return(["backtrace line 1", "backtrace line 2"])

      processor.send(:log_error, error)

      expect(Rails.logger).to have_received(:error).with(error.backtrace.join("\n"))
    end
  end

  describe "#attempt_move_to_dlq" do
    before do
      allow(Rails.logger).to receive(:error)
    end

    it "delegates to move_to_dlq" do
      allow(processor).to receive(:move_to_dlq)

      processor.send(:attempt_move_to_dlq, error)

      expect(processor).to have_received(:move_to_dlq).with(error)
    end

    context "when move_to_dlq raises an error" do
      before do
        # Use a local variable for dlq_error in the before block
        dlq_error = StandardError.new("DLQ error")
        allow(processor).to receive(:move_to_dlq).and_raise(dlq_error)
      end

      it "logs the error" do
        # Create a new dlq_error for this test
        dlq_error = StandardError.new("DLQ error")
        allow(processor).to receive(:move_to_dlq).and_raise(dlq_error)

        suppress(StandardError) do
          processor.send(:attempt_move_to_dlq, error)
          expect(Rails.logger).to have_received(:error).with("Failed to move message to DLQ: DLQ error")
        end
      end

      it "re-raises the error" do
        # Create a new dlq_error for this test
        dlq_error = StandardError.new("DLQ error")
        allow(processor).to receive(:move_to_dlq).and_raise(dlq_error)

        expect { processor.send(:attempt_move_to_dlq, error) }.to raise_error(dlq_error)
      end
    end
  end

  describe "#log_dlq_not_configured" do
    before do
      allow(Rails.logger).to receive(:warn)
    end

    it "logs a warning about DLQ not being configured" do
      processor.send(:log_dlq_not_configured)

      expect(Rails.logger).to have_received(:warn)
        .with("Message test-message-id exceeded max retries but DLQ not configured")
    end
  end

  describe "#dlq_message_attributes" do
    before do
      allow(Time).to receive(:current).and_return(Time.new(2023, 1, 1, 12, 0, 0, 0))
    end

    let(:retry_count) { 3 }
    let(:queue_url) { "original-queue-url" }
    let(:message) do
      instance_double(
        Aws::SQS::Types::Message,
        body: "test body",
        message_id: "test-message-id",
        message_attributes: { "existing" => "attribute" },
        attributes: { "ApproximateReceiveCount" => retry_count.to_s }
      )
    end
    let(:processor) { DummyProcessor.new(message, queue_url: queue_url) }
    let(:error) { StandardError.new("test error") }

    it "includes error information" do
      result = processor.send(:dlq_message_attributes, error)

      expect(result).to include(
        "original_queue" => { data_type: "String", string_value: queue_url },
        "failure_reason" => { data_type: "String", string_value: "test error" }
      )
    end

    it "includes retry count and timestamp" do
      result = processor.send(:dlq_message_attributes, error)

      expect(result).to include(
        "retry_count" => { data_type: "Number", string_value: "3" },
        "failed_at" => { data_type: "String", string_value: "2023-01-01T12:00:00+00:00" }
      )
    end
  end

  describe "#log_dlq_success" do
    before do
      allow(Rails.logger).to receive(:info)
    end

    it "logs success message with message ID" do
      processor.send(:log_dlq_success)

      expect(Rails.logger).to have_received(:info)
        .with("Moved failed message to DLQ: test-message-id")
    end
  end

  describe "#handle_processing_error" do
    before do
      allow(Rails.logger).to receive(:error)
      allow(Rails.logger).to receive(:warn)
      allow(Rails.logger).to receive(:info)
    end

    let(:retry_count) { 4 }
    let(:message) do
      instance_double(
        Aws::SQS::Types::Message,
        body: "test body",
        message_id: "test-message-id",
        message_attributes: {},
        attributes: { "ApproximateReceiveCount" => retry_count.to_s }
      )
    end
    let(:processor) { DummyProcessor.new(message, queue_url: queue_url) }
    let(:error) { StandardError.new("test error") }

    context "when DLQ is configured" do
      before do
        allow(CleverEvents.configuration).to receive(:sqs_dlq_url).and_return("dlq-url")
        allow(processor).to receive(:attempt_move_to_dlq)
      end

      it "attempts to move message to DLQ" do
        processor.send(:handle_processing_error, error)

        expect(processor).to have_received(:attempt_move_to_dlq).with(error)
      end
    end

    context "when DLQ is not configured" do
      before do
        allow(CleverEvents.configuration).to receive(:sqs_dlq_url).and_return(nil)
        allow(processor).to receive(:log_dlq_not_configured)
      end

      it "logs that DLQ is not configured" do
        processor.send(:handle_processing_error, error)

        expect(processor).to have_received(:log_dlq_not_configured)
      end

      it "does not attempt to move message to DLQ" do
        allow(processor).to receive(:attempt_move_to_dlq)

        processor.send(:handle_processing_error, error)

        expect(processor).not_to have_received(:attempt_move_to_dlq)
      end
    end
  end

  describe "#move_to_dlq" do
    before do
      allow(CleverEvents.configuration).to receive(:sqs_dlq_url).and_return("dlq-url")
      allow(CleverEvents::Adapters::SqsAdapter).to receive(:send_message).and_return(true)
      allow(processor).to receive(:log_dlq_success)
    end

    let(:retry_count) { 3 }
    let(:queue_url) { "original-queue-url" }
    let(:message) do
      instance_double(
        Aws::SQS::Types::Message,
        body: "test body",
        message_id: "test-message-id",
        message_attributes: {},
        attributes: { "ApproximateReceiveCount" => retry_count.to_s }
      )
    end
    let(:processor) { DummyProcessor.new(message, queue_url: queue_url) }
    let(:error) { StandardError.new("test error") }

    it "sends the message to the DLQ" do
      processor.send(:move_to_dlq, error)

      expect(CleverEvents::Adapters::SqsAdapter).to have_received(:send_message)
    end

    it "logs success after moving to DLQ" do
      processor.send(:move_to_dlq, error)

      expect(processor).to have_received(:log_dlq_success)
    end
  end
end
