# frozen_string_literal: true

module CleverEvents
  class Message
    MESSAGE_VERSION = "1.0"

    attr_reader :event_name, :entity

    def initialize(event_name, entity)
      @event_name = event_name
      @entity = entity
    end

    def build_message
      {
        event_name:,
        entity_type:,
        entity_id:,
        path:
      }.to_json
    end

    def message_attributes
      {
        event_name: string_attribute(event_name),
        source: string_attribute(source),
        time: string_attribute(timestamp),
        message_version: string_attribute(MESSAGE_VERSION)
      }
    end

    private

    def path
      "#{base_api_url}/#{entity_type.underscore.pluralize}/#{entity_id}"
    end

    def entity_type
      entity.class.to_s.underscore.downcase
    end

    def entity_id
      entity.id
    end

    def base_api_url
      CleverEvents.configuration.base_api_url
    end

    def source
      CleverEvents.configuration.source
    end

    def timestamp
      Time.now.iso8601
    end

    def string_attribute(value)
      {
        string_value: value,
        data_type: "String"
      }
    end
  end
end
