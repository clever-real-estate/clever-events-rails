# frozen_string_literal: true

require "spec_helper"

RSpec.describe CleverEvents::Adapters::SnsAdapter, type: :model do
  describe ".publish" do
    let(:sns_client) { Aws::SNS::Client.new(stub_responses: true) }
    let(:test_object) { build_stubbed(:test_object) }

    before do
      allow(Aws::SNS::Client).to receive(:new).and_return(sns_client)
      allow(sns_client).to receive(:publish)
    end

    it "publishes a message to the sns topic" do
      described_class.publish_event("test_event", test_object)

      expect(sns_client).to have_received(:publish)
    end

    describe "when the topic_arn is not set" do
      it "raises an error" do
        allow(CleverEvents.configuration).to receive(:sns_topic_arn).and_return(nil)

        expect do
          described_class.publish_event("test_event", test_object)
        end.to raise_error(RuntimeError, "Invalid topic config")
      end
    end
  end
end
