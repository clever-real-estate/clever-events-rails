# frozen_string_literal: true

require "active_support"
require "active_support/core_ext"

module CleverEvents
  module Publishable
    extend ActiveSupport::Concern

    attr_accessor :skip_publish, :topic_arn

    included do
      class_attribute :_publishable_attrs, default: []
      class_attribute :_publishable_actions, default: %i[created updated destroyed]
      class_attribute :_publishable_topic_arn, default: nil

      def publish_event!
        CleverEvents::Publisher.publish_event!(event_name, self, message_deduplication_id, custom_topic_arn)
      rescue StandardError => e
        raise CleverEvents::Error, e.message
      end

      private

      def event_name
        "#{self.class.name}.#{event_type}"
      end

      def message_deduplication_id
        SecureRandom.uuid
      end

      def custom_topic_arn
        topic_arn || self.class._publishable_topic_arn
      end
    end

    module ClassMethods
      def publishable_attrs(*attrs)
        self._publishable_attrs = attrs.flatten
      end

      def publishable_actions(*actions)
        self._publishable_actions = actions.flatten
      end

      def publishable_topic_arn(arn)
        self._publishable_topic_arn = arn
      end
    end

    def publish_event?
      return false if self.class._publishable_attrs.empty?
      return false unless self.class._publishable_actions.include?(event_type)
      return false if skip_publish?

      return true if event_type == :destroyed

      self.class._publishable_attrs.intersection(changes).any?
    end

    def skip_publish?
      !!@skip_publish
    end

    def changes
      previous_changes.symbolize_keys.keys
    end

    def event_type
      if destroyed?
        :destroyed
      elsif saved_change_to_id?
        :created
      else
        :updated
      end
    end
  end
end
