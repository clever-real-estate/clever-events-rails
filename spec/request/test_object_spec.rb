# frozen_string_literal: true

require "spec_helper"

module CleverEventsRails
  RSpec.describe "Integration Test", type: :request do
    describe "PATCH /test_objects/:id" do
      let(:test_object) { create(:test_object) }
      let(:valid_attributes) { { name: "Updated Name" } }
      let(:sns_client) { Aws::SNS::Client.new(stub_responses: true) }

      before do
        allow(Aws::SNS::Client).to receive(:new).and_return(sns_client)
      end

      context "when the request is valid" do
        it "publishes an event to SNS" do
          expect(sns_client).to receive(:publish).and_call_original # rubocop:disable RSpec/MessageSpies

          patch Rails.application.routes.url_helpers.test_object_path(test_object, valid_attributes)
        end
      end
    end
  end
end
