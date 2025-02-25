# frozen_string_literal: true

require "spec_helper"

RSpec.describe CleverEvents::Publishable do
  let(:test_object) { build_stubbed(:test_object) }
  let(:test_uuid) { "test_uuid" }

  before do
    allow(SecureRandom).to receive(:uuid).and_return(test_uuid)
    allow(CleverEvents::Publisher).to receive(:publish_event!)
  end

  describe ".publishable_attrs" do
    it "defines the attributes to be published" do
      expect(test_object.class._publishable_attrs).to eq(%i[first_name last_name email phone])
    end

    describe "when a publishable attribute is updated" do
      let(:test_object) { create(:test_object) }

      it "calls the publish_event! method" do
        test_object.update(first_name: "New Name")
        expect(CleverEvents::Publisher).to have_received(:publish_event!)
          .with("TestObject.updated", test_object, test_uuid)
      end
    end

    describe "when a model doesn't have publishable attributes" do
      let(:test_object) { create(:test_object) }

      it "does not call publish_event!" do
        allow(TestObject).to receive(:_publishable_attrs).and_return([])
        test_object.update(first_name: "new name")
        expect(CleverEvents::Publisher).not_to have_received(:publish_event!)
      end
    end

    describe "when a non-publishable attribute is updated" do
      let(:test_object) { create(:test_object) }

      it "does not call publish_event!" do
        allow(TestObject).to receive(:_publishable_attrs).and_return([:first_name])
        test_object.update(last_name: "New Name")
        expect(CleverEvents::Publisher).not_to have_received(:publish_event!).with("test_object.updated", test_object)
      end
    end
  end

  describe ".publishable_actions" do
    let(:test_object) { build_stubbed(:test_object) }

    before do
      allow(test_object).to receive(:_publishable_actions).and_return(%i[created updated destroyed])
    end

    it "defines the actions to be published" do
      expect(test_object.class._publishable_actions).to eq(%i[updated])
    end

    describe "when a publishable action is performed" do
      let(:test_object) { create(:test_object) }

      it "calls the publish_event! method" do
        test_object.update(first_name: "New Name")
        expect(CleverEvents::Publisher).to have_received(:publish_event!)
          .with("TestObject.updated", test_object, test_uuid)
      end

      describe "when publish_event! raises an error" do
        let(:test_object) { build_stubbed(:test_object) }

        it "logs an error" do
          allow(CleverEvents::Publisher).to receive(:publish_event!).and_raise(StandardError)

          expect { test_object.publish_event! }.to raise_error(CleverEvents::Error)
        end
      end
    end

    describe "when a model doesn't have publishable actions" do
      it "does not call publish_event!" do
        allow(TestObject).to receive(:_publishable_actions).and_return([])
        test_object = create(:test_object)
        test_object.destroy
        expect(CleverEvents::Publisher).not_to have_received(:publish_event!)
      end
    end

    describe "when a non-publishable action is performed" do
      it "does not call publish_event!" do
        allow(TestObject).to receive(:_publishable_actions).and_return([:update])
        test_object = create(:test_object)
        test_object.destroy
        expect(CleverEvents::Publisher).not_to have_received(:publish_event!)
      end
    end
  end
end
