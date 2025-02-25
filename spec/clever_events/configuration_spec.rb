# frozen_string_literal: true

require "spec_helper"

RSpec.describe CleverEvents::Configuration, type: :model do
  describe "#initialize" do
    it "sets default values" do # rubocop:disable RSpec/MultipleExpectations
      config = described_class.new

      expect(config.publish_events).to be false
      expect(config.events_adapter).to eq(CleverEvents::Adapters::SnsAdapter)
      expect(config.aws_access_key_id).to be_nil
      expect(config.aws_secret_access_key).to be_nil
      expect(config.aws_region).to eq("us-east-1")
    end
  end

  describe "#configure" do
    it "allows configuration of values" do # rubocop:disable RSpec/MultipleExpectations
      # stub config object to not affect other tests
      allow(CleverEvents).to receive(:configuration).and_return(described_class.new)

      CleverEvents.configure do |config|
        config.publish_events = false
        config.events_adapter = :sns
        config.aws_access_key_id = "new_access_key"
        config.aws_secret_access_key = "new_secret_key"
        config.aws_region = "us-west-2"
      end

      config = CleverEvents.configuration

      expect(config.publish_events).to be false
      expect(config.events_adapter).to eq(CleverEvents::Adapters::SnsAdapter)
      expect(config.aws_access_key_id).to eq("new_access_key")
      expect(config.aws_secret_access_key).to eq("new_secret_key")
      expect(config.aws_region).to eq("us-west-2")
    end
  end
end
