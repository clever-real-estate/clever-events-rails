# frozen_string_literal: true

require "spec_helper"

RSpec.describe CleverEvents::Configuration do
  let(:config) { described_class.new }

  describe "#initialize" do
    it "sets default values" do # rubocop:disable RSpec/MultipleExpectations
      expect(config.sns_topic_arn).to be_nil
      expect(config.sqs_queue_url).to be_nil
      expect(config.publish_events).to be false
      expect(config.events_adapter).to eq(CleverEvents::Adapters::SnsAdapter)
      expect(config.message_processor_adapter).to eq(CleverEvents::Adapters::SqsAdapter)
      expect(config.fifo_topic?).to be false
      expect(config.default_message_batch_size).to eq(1)
    end
  end

  describe "#configure" do
    it "allows configuration of values" do # rubocop:disable RSpec/MultipleExpectations
      allow(CleverEvents).to receive(:configuration).and_return(described_class.new)

      CleverEvents.configure do |config|
        config.publish_events = true
        config.sns_topic_arn = "test-arn"
        config.aws_region = "us-west-2"
      end

      expect(CleverEvents.configuration.publish_events).to be true
      expect(CleverEvents.configuration.sns_topic_arn).to eq("test-arn")
      expect(CleverEvents.configuration.aws_region).to eq("us-west-2")
    end
  end

  describe "#events_adapter" do
    it "returns the sns adapter class when configured with :sns" do
      config.events_adapter = :sns
      expect(config.events_adapter).to eq(CleverEvents::Adapters::SnsAdapter)
    end

    it "returns the sqs adapter class when configured with :sqs" do
      config.events_adapter = :sqs
      expect(config.events_adapter).to eq(CleverEvents::Adapters::SqsAdapter)
    end

    it "returns the default adapter when an invalid adapter key is provided" do
      config.events_adapter = :invalid
      expect(config.events_adapter).to eq(CleverEvents::Adapters::SnsAdapter)
    end
  end

  describe "#message_processor_adapter" do
    it "returns the sqs adapter class when configured with :sqs" do
      config.message_processor_adapter = :sqs
      expect(config.message_processor_adapter).to eq(CleverEvents::Adapters::SqsAdapter)
    end

    it "returns the sns adapter class when configured with :sns" do
      config.message_processor_adapter = :sns
      expect(config.message_processor_adapter).to eq(CleverEvents::Adapters::SnsAdapter)
    end

    it "returns the default adapter when an invalid adapter key is provided" do
      config.message_processor_adapter = :invalid
      expect(config.message_processor_adapter).to eq(CleverEvents::Adapters::SqsAdapter)
    end
  end

  describe "#fifo_topic?" do
    it "returns false by default" do
      expect(config.fifo_topic?).to be false
    end

    it "returns true when fifo_topic is set to true" do
      config.instance_variable_set(:@fifo_topic, true)
      expect(config.fifo_topic?).to be true
    end
  end
end
