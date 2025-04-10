# frozen_string_literal: true

require "spec_helper"

RSpec.describe CleverEvents::Message, type: :model do
  describe "#body" do
    let(:entity) { build_stubbed(:test_object) }
    let(:event) { described_class.new("test_object.updated", entity) }

    it "returns the correct json body" do
      expect(event.build_message).to eq({
        event_name: "test_object.updated",
        entity_type: "test_object",
        entity_id: entity.id,
        path: "http://localhost:3000/api/test_objects/#{entity.id}"
      }.to_json)
    end
  end
end
