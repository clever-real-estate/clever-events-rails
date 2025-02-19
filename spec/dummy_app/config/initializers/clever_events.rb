# frozen_string_literal: true

CleverEvents.configure do |config|
  config.publish_events = true
  config.sns_topic_arn = "arn:aws:sns:us-east-1:000000000000:my-test-topic"
end
