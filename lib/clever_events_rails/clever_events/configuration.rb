# frozen_string_literal: true

module CleverEvents
  class Configuration
    ADAPTERS = {
      sns: CleverEvents::Adapters::SnsAdapter
    }.freeze

    DEFAULT_AWS_REGION = "us-east-1"
    DEFAULT_EVENTS_ADAPTER = :sns
    DEFAULT_PUBLISH_EVENTS = false

    attr_accessor :aws_access_key_id,
                  :aws_secret_access_key,
                  :aws_region,
                  :publish_events,
                  :sns_topic_arn
    attr_writer :events_adapter

    def initialize
      @events_adapter = DEFAULT_EVENTS_ADAPTER
      @aws_access_key_id = nil
      @aws_secret_access_key = nil
      @aws_region = DEFAULT_AWS_REGION
      @sns_topic_arn = nil
      @publish_events = DEFAULT_PUBLISH_EVENTS
    end

    def events_adapter
      ADAPTERS[@events_adapter] || CleverEvents::Adapters::SnsAdapter
    end
  end
end
