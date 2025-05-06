# frozen_string_literal: true

require "spec_helper"

class DummyProcessor < CleverEvents::Processor
  def process_message
    # Implementation for testing
  end
end

# Processor without process_message implementation
class EmptyProcessor < CleverEvents::Processor
  # Intentionally not implementing process_message
end

RSpec.describe CleverEvents::Processor do
  let(:queue_url) { "https://sqs.region.amazonaws.com/account-id/queue-name" }
  let(:retry_count) { 1 }
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
    it "creates a processor instance with correct parameters" do
      allow(DummyProcessor).to receive(:new).with(message, queue_url: queue_url).and_call_original
      DummyProcessor.process(message, queue_url: queue_url)
      expect(DummyProcessor).to have_received(:new).with(message, queue_url: queue_url)
    end

    it "calls process on the processor instance" do
      instance = instance_spy(DummyProcessor)
      allow(DummyProcessor).to receive(:new).and_return(instance)

      DummyProcessor.process(message, queue_url: queue_url)

      expect(instance).to have_received(:process)
    end
  end

  describe "#initialize" do
    it "sets the message" do
      processor = DummyProcessor.new(message, queue_url: queue_url)
      expect(processor.send(:message)).to eq(message)
    end

    it "sets the queue_url" do
      processor = DummyProcessor.new(message, queue_url: queue_url)
      expect(processor.send(:queue_url)).to eq(queue_url)
    end

    it "sets the retry count from message attributes" do
      processor = DummyProcessor.new(message, queue_url: queue_url)

      expect(processor.send(:retry_count)).to eq(1)
    end
  end

  describe "#process" do
    it "calls process_message" do
      allow(processor).to receive(:process_message)

      processor.process

      expect(processor).to have_received(:process_message)
    end

    it "raises NotImplementedError when process_message is not implemented" do
      empty_processor = EmptyProcessor.new(message, queue_url: queue_url)

      expect { empty_processor.process }.to raise_error(
        NotImplementedError,
        "EmptyProcessor must implement process_message method"
      )
    end

    context "when an error occurs" do
      before do
        allow(Rails.logger).to receive(:error)
        allow(Rails.logger).to receive(:info)
        allow(processor).to receive(:process_message).and_raise(error)
      end

      it "logs the error message" do
        # Suppress the actual error to focus on the logging behavior
        allow(processor).to receive(:raise)

        begin
          processor.process
        rescue StandardError
          nil
        end

        expect(Rails.logger).to have_received(:error).with("Failed to process message: test error")
      end

      it "re-raises the error for SQS to handle" do
        expect { processor.process }.to raise_error(error)
      end

      it "logs that SQS will retry the message" do
        suppress(StandardError) do
          processor.process
        end

        expect(Rails.logger).to have_received(:info).with("Message will be retried by SQS (current retry count: 1)")
      end
    end
  end

  describe "#log_error" do
    before do
      allow(Rails.logger).to receive(:error)
      allow(Rails.logger).to receive(:info)
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

    it "logs the error message when backtrace is nil" do
      allow(error).to receive(:backtrace).and_return(nil)
      processor.send(:log_error, error)

      expect(Rails.logger).to have_received(:error).with("Failed to process message: test error")
    end

    it "does not attempt to log nil backtrace" do
      allow(error).to receive(:backtrace).and_return(nil)

      processor.send(:log_error, error)

      expect(Rails.logger).to have_received(:error).exactly(1).times
    end

    it "logs a message about SQS retrying" do
      processor.send(:log_error, error)

      expect(Rails.logger).to have_received(:info).with("Message will be retried by SQS (current retry count: 1)")
    end
  end
end
