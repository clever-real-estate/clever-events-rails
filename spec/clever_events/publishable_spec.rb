# frozen_string_literal: true

require "spec_helper"

RSpec.describe CleverEvents::Publishable do
  let(:test_object) { build_stubbed(:test_object) }
  let(:test_uuid) { "test_uuid" }
  let(:custom_arn) { "arn:aws:sns:us-east-1:123456789012:custom-topic" }

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
          .with("TestObject.updated", test_object, test_uuid, nil)
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
      allow(test_object.class).to receive(:_publishable_actions).and_return(%i[created updated destroyed])
    end

    it "defines the actions to be published" do
      expect(test_object.class._publishable_actions).to eq(%i[created updated destroyed])
    end

    describe "when a publishable action is performed" do
      let(:test_object) { create(:test_object) }

      before do
        allow(test_object.class).to receive(:_publishable_actions).and_return(%i[destroyed])
      end

      it "calls the publish_event! method" do
        test_object.destroy
        expect(CleverEvents::Publisher).to have_received(:publish_event!)
          .with("TestObject.destroyed", test_object, test_uuid, nil)
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

  describe "skipping publish" do
    let(:test_object) { create(:test_object) }

    describe "when skip_publish is true" do
      it "does not call publish_event!" do
        test_object.update(first_name: "New Name", skip_publish: true)

        expect(CleverEvents::Publisher).not_to have_received(:publish_event!)
      end
    end

    describe "when skip_publish is false" do
      it "calls publish_event!" do
        test_object.update(first_name: "New Name", skip_publish: false)

        expect(CleverEvents::Publisher).to have_received(:publish_event!)
          .with("TestObject.updated", test_object, test_uuid, nil)
      end
    end

    describe "when skip_publish is not set" do
      it "calls publish_event!" do
        test_object.update(first_name: "New Name")

        expect(CleverEvents::Publisher).to have_received(:publish_event!)
          .with("TestObject.updated", test_object, test_uuid, nil)
      end
    end
  end

  describe ".publishable_topic_arn" do
    before do
      TestObject.publishable_topic_arn(custom_arn)
    end

    after do
      TestObject.publishable_topic_arn(nil)
    end

    it "sets the class-level topic ARN" do
      expect(TestObject._publishable_topic_arn).to eq(custom_arn)
    end

    describe "when publishing an event" do
      let(:test_object) { create(:test_object) }

      it "uses the custom topic ARN" do
        test_object.update(first_name: "New Name")
        expect(CleverEvents::Publisher).to have_received(:publish_event!)
          .with("TestObject.updated", test_object, test_uuid, custom_arn)
      end
    end
  end

  describe "instance-level topic_arn" do
    let(:test_object) { create(:test_object) }
    let(:instance_arn) { "arn:aws:sns:us-east-1:123456789012:instance-topic" }

    describe "when instance topic_arn is set" do
      it "uses the instance topic ARN" do
        test_object.topic_arn = instance_arn
        test_object.update(first_name: "New Name")
        expect(CleverEvents::Publisher).to have_received(:publish_event!)
          .with("TestObject.updated", test_object, test_uuid, instance_arn)
      end
    end

    describe "when both class and instance topic ARNs are set" do
      before do
        TestObject.publishable_topic_arn(custom_arn)
      end

      after do
        TestObject.publishable_topic_arn(nil)
      end

      it "prioritizes the instance topic ARN" do
        test_object.topic_arn = instance_arn
        test_object.update(first_name: "New Name")
        expect(CleverEvents::Publisher).to have_received(:publish_event!)
          .with("TestObject.updated", test_object, test_uuid, instance_arn)
      end
    end

    describe "when only class topic ARN is set" do
      before do
        TestObject.publishable_topic_arn(custom_arn)
      end

      after do
        TestObject.publishable_topic_arn(nil)
      end

      it "uses the class topic ARN" do
        test_object.update(first_name: "New Name")
        expect(CleverEvents::Publisher).to have_received(:publish_event!)
          .with("TestObject.updated", test_object, test_uuid, custom_arn)
      end
    end
  end
end
