# frozen_string_literal: true

module CleverEvents
  class Configuration
    ADAPTERS = {
      sns: CleverEvents::Adapters::SnsAdapter,
      sqs: CleverEvents::Adapters::SqsAdapter
    }.freeze

    DEFAULT_AWS_REGION = "us-east-1"
    DEFAULT_EVENTS_ADAPTER = :sns
    DEFAULT_MESSAGE_PROCESSOR_ADAPTER = :sqs
    DEFAULT_PUBLISH_EVENTS = false
    DEFAULT_MESSAGE_BATCH_SIZE = 1
    DEFAULT_SOURCE = "clever_events_rails"

    attr_accessor :aws_access_key_id,
                  :aws_secret_access_key,
                  :aws_region,
                  :publish_events,
                  :sns_topic_arn,
                  :base_api_url,
                  :sqs_queue_url,
                  :default_message_batch_size,
                  :source,
                  :sqs_dlq_url
    attr_writer :events_adapter,
                :message_processor_adapter

    def initialize # rubocop:disable Metrics/MethodLength
      @events_adapter = DEFAULT_EVENTS_ADAPTER
      @message_processor_adapter = DEFAULT_MESSAGE_PROCESSOR_ADAPTER
      @aws_access_key_id = nil
      @aws_secret_access_key = nil
      @aws_region = DEFAULT_AWS_REGION
      @sns_topic_arn = nil
      @sqs_queue_url = nil
      @publish_events = DEFAULT_PUBLISH_EVENTS
      @default_message_batch_size = DEFAULT_MESSAGE_BATCH_SIZE
      @fifo_topic = false
      @source = DEFAULT_SOURCE
      @sqs_dlq_url = nil
    end

    def events_adapter
      ADAPTERS[@events_adapter] || CleverEvents::Adapters::SnsAdapter
    end

    def message_processor_adapter
      ADAPTERS[@message_processor_adapter] || CleverEvents::Adapters::SqsAdapter
    end

    def fifo_topic?
      @fifo_topic
    end
  end
end
