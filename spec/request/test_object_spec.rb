# frozen_string_literal: true

require "spec_helper"

module CleverEventsRails
  RSpec.describe "Integration Test", type: :request do
    describe "PATCH /test_objects/:id" do
      let!(:test_object) { create(:test_object) }
      let(:logger) { Rails.logger }

      context "when the request is valid" do
        let(:valid_attributes) { { test_object: { first_name: "Updated Name" } } }

        it "publishes an event to SNS" do
          VCR.use_cassette("event_publishing/success") do
            allow(logger).to receive(:info)

            patch Rails.application.routes.url_helpers.test_object_path(test_object, valid_attributes)

            expect(logger).to have_received(:info)
              .with("Event published to SNS message_id: 5b689a32-5a9e-50e7-861e-fa009418f6f9")
          end
        end

        context "when an error is returned from sns" do
          let(:sns_client) { Aws::SNS::Client.new(stub_responses: true) }

          it "raises an error" do
            VCR.use_cassette("event_publishing/failure") do
              allow(logger).to receive(:error)

              expect { patch Rails.application.routes.url_helpers.test_object_path(test_object, valid_attributes) }
                .to raise_error(CleverEvents::Error)
            end
          end
        end

        context "when using custom topic ARN" do
          let(:custom_arn) { "arn:aws:sns:us-east-1:123456789012:custom-topic" }
          let(:sns_client) { Aws::SNS::Client.new(stub_responses: true) }

          before do
            TestObject.publishable_topic_arn(custom_arn)
            allow(Aws::SNS::Client).to receive(:new).and_return(sns_client)
            allow(sns_client).to receive(:publish).and_return(
              Aws::SNS::Types::PublishResponse.new(message_id: "custom-message-id")
            )
          end

          after do
            TestObject.publishable_topic_arn(nil)
          end

          it "publishes to the custom topic ARN" do
            patch Rails.application.routes.url_helpers.test_object_path(test_object, valid_attributes)

            expect(sns_client).to have_received(:publish).with(
              hash_including(topic_arn: custom_arn)
            )
          end
        end
      end

      context "when the request is invalid" do
        let(:invalid_attributes) { { test_object: { first_name: nil } } }
        let(:sns_client) { Aws::SNS::Client.new(stub_responses: true) }

        it "does not attempt to publish an event to SNS" do
          VCR.use_cassette("event_publishing/failure") do
            allow(sns_client).to receive(:publish)

            patch Rails.application.routes.url_helpers.test_object_path(test_object, invalid_attributes)

            expect(sns_client).not_to have_received(:publish)
          end
        end
      end
    end
  end
end
