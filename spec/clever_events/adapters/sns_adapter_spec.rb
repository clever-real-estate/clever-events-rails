# frozen_string_literal: true

require "spec_helper"

RSpec.describe CleverEvents::Adapters::SnsAdapter, type: :model do
  describe ".publish" do
    let(:sns_client) { Aws::SNS::Client.new(stub_responses: true) }
    let(:test_object) { build_stubbed(:test_object) }
    let(:test_uuid) { "test_uuid" }

    before do
      allow(Aws::SNS::Client).to receive(:new).and_return(sns_client)
      allow(sns_client).to receive(:publish)
      allow(SecureRandom).to receive(:uuid).and_return(test_uuid)
    end

    it "publishes a message to the sns topic" do
      described_class.publish_event("test_event", test_object, test_uuid)

      expect(sns_client).to have_received(:publish).with(
        topic_arn: CleverEvents.configuration.sns_topic_arn,
        message: CleverEvents::Message.new("test_event", test_object).build_message,
        subject: "test_event",
        message_group_id: "test_object.#{test_object.id}",
        message_deduplication_id: test_uuid
      )
    end

    describe "when the topic_arn is not set" do
      it "raises an error" do
        allow(CleverEvents.configuration).to receive(:sns_topic_arn).and_return(nil)

        expect do
          described_class.publish_event("test_event", test_object, test_uuid)
        end.to raise_error(CleverEvents::Error, "Invalid topic config")
      end
    end
  end
end
