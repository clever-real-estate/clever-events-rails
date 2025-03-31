# frozen_string_literal: true

CleverEvents.configure do |config|
  config.publish_events = true
  config.events_adapter = :sns
  config.sns_topic_arn = ENV.fetch("SNS_TOPIC_ARN", "arn:aws:sns:us-east-1:123456789012:clever-events")
  config.sqs_queue_url = ENV.fetch("SQS_QUEUE_URL", "https://sqs.test.amazonaws.com/123456789012/test-queue")
  config.aws_access_key_id = ENV.fetch("AWS_ACCESS_KEY_ID", "fake_access_key")
  config.aws_secret_access_key = ENV.fetch("AWS_SECRET_ACCESS_KEY", "fake_secret_key")
  config.aws_region = ENV.fetch("AWS_REGION", "us-east-1")
  config.base_api_url = "http://localhost:3000/api"
  config.message_processor_adapter = :sqs
  config.default_message_batch_size = 10
end
