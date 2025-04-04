# frozen_string_literal: true

module CleverEvents
  class Message
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

    private

    def path
      "#{base_api_url}/#{entity_type.underscore.pluralize}/#{entity_id}"
    end

    def entity_type
      entity.class.to_s
    end

    def entity_id
      entity.id
    end

    def base_api_url
      CleverEvents.configuration.base_api_url
    end
  end
end
