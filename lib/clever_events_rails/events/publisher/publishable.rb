# frozen_string_literal: true

require "active_support"
require "active_support/core_ext"

module Events
  module Publisher
    module Publishable
      extend ActiveSupport::Concern

      included do
        class_attribute :_publishable_attrs, default: []
        class_attribute :_publishable_actions, default: %i[created updated destroyed]
      end

      module ClassMethods
        def publishable_attrs(*attrs)
          self._publishable_attrs = attrs.flatten
        end

        def publishable_actions(*actions)
          self._publishable_actions = actions.flatten
        end
      end

      private

      def publish_event?
        return false if self.class._publishable_attrs.empty?
        return false unless self.class._publishable_actions.include?(event_type)

        self.class._publishable_attrs.intersection(changes).any?
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

      def event_name
        "#{self.class.name.underscore}.#{event_type}"
      end
    end
  end
end
