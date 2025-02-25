# frozen_string_literal: true

require "spec_helper"

RSpec.describe CleverEvents::Publisher do
  describe ".publish_event" do
    let(:test_object) { build_stubbed(:test_object) }
    let(:client) { Aws::SNS::Client.new(stub_responses: true) }
    let(:adapter_class) { CleverEvents::Adapters::SnsAdapter }
    let(:test_uuid) { "test_uuid" }

    before do
      allow(SecureRandom).to receive(:uuid).and_return(test_uuid)
      allow(described_class).to receive(:event_adapter).and_return(adapter_class)
      allow(Aws::SNS::Client).to receive(:new).and_return(client)
      allow(client).to receive(:publish)
    end

    describe "when event publishing is disabled" do
      let(:config) { CleverEvents.configuration }

      it "does not publish an event" do
        allow(config).to receive(:publish_events).and_return(false)

        described_class.publish_event!("test_object.updated", test_object, test_uuid)
        expect(client).not_to have_received(:publish)
      end
    end

    describe "when event publishing is enabled" do
      describe "when using the sns adapter" do
        it "publishes an event to sns topic" do
          described_class.publish_event!("test_object.updated", test_object, test_uuid)

          expect(client).to have_received(:publish)
        end

        describe "when giving a custom topic_arn" do
          it "publishes an event to the given sns topic" do
            described_class.publish_event!("test_object.updated", test_object, test_uuid, "custom_topic_arn")

            expect(client).to have_received(:publish).with(hash_including(topic_arn: "custom_topic_arn"))
          end
        end

        describe "when the sns client raises an error" do
          before do
            allow(client).to receive(:publish).and_raise(StandardError.new("This is a test error"))
            allow(Rails.logger).to receive(:error)
          end

          it "raises an error" do
            expect do
              described_class.publish_event!("test_object.updated", test_object, test_uuid)
            end.to raise_error(CleverEvents::Error, "This is a test error")
          end
        end
      end
    end
  end
end
