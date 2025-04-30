# CleverEventsRails

A Rails engine for publishing and processing events using AWS SNS and SQS.

## Installation

Add this line to your application's Gemfile:

```ruby
gem "clever_events_rails"
```

And then execute:

```bash
$ bundle install
```

Or install it yourself as:

```bash
$ gem install clever_events_rails
```

## Usage

### Configuration

Configure the gem in an initializer:

```ruby
# config/initializers/clever_events.rb
CleverEvents.configure do |config|
  # Enable or disable event publishing (default: false)
  config.publish_events = true

  # AWS Credentials
  config.aws_access_key_id = "your-access-key"
  config.aws_secret_access_key = "your-secret-key"
  config.aws_region = "us-east-1"

  # SNS Configuration
  config.sns_topic_arn = "arn:aws:sns:region:account-id:topic-name"
  # Set to true if using FIFO topics (default: false)
  config.fifo_topic = true

  # SQS Configuration
  config.sqs_queue_url = "https://sqs.region.amazonaws.com/account-id/queue-name"
  # Optional Dead Letter Queue (DLQ) for failed messages
  config.sqs_dlq_url = "https://sqs.region.amazonaws.com/account-id/dead-letter-queue-name"

  # API Configuration
  # Base URL for generating paths to API resources
  config.base_api_url = "http://localhost:3000/api"

  # Batch Processing
  # Number of messages to process in a batch (default: 1)
  config.default_message_batch_size = 10

  # Event Source
  # Custom source identifier for published events (default: "clever_events_rails")
  config.source = "my_application_name"

  # Adapter Selection
  # Choose adapter for publishing events: (default: :sns)
  config.events_adapter = :sns
  # Choose adapter for processing messages: (default: :sqs)
  config.message_processor_adapter = :sqs
end
```

#### Configuration Options

| Option                       | Description                                                    | Default                 |
| ---------------------------- | -------------------------------------------------------------- | ----------------------- |
| `publish_events`             | Enable or disable event publishing                             | `false`                 |
| `aws_access_key_id`          | AWS access key ID                                              | `nil`                   |
| `aws_secret_access_key`      | AWS secret access key                                          | `nil`                   |
| `aws_region`                 | AWS region                                                     | `"us-east-1"`           |
| `sns_topic_arn`              | ARN of the SNS topic to publish events to                      | `nil`                   |
| `fifo_topic`                 | Set to true when using FIFO topics to enable deduplication IDs | `false`                 |
| `sqs_queue_url`              | URL of the SQS queue to receive messages from                  | `nil`                   |
| `sqs_dlq_url`                | URL of the Dead Letter Queue for failed messages               | `nil`                   |
| `base_api_url`               | Base URL for generating API resource paths                     | `nil`                   |
| `default_message_batch_size` | Number of messages to process in a batch                       | `1`                     |
| `source`                     | Custom source identifier for published events                  | `"clever_events_rails"` |
| `events_adapter`             | Adapter for publishing events (`:sns`)                         | `:sns`                  |
| `message_processor_adapter`  | Adapter for processing messages (`:sns`)                       | `:sqs`                  |

### Publishing Events

Include the `Publishable` module in your models:

```ruby
class User < ApplicationRecord
  include CleverEvents::Publishable

  publishable_attrs :name, :email
  publishable_actions :create, :update, :destroy
end
```

Events will be published to SNS when:

- A publishable attribute is updated
- A publishable action is performed

### Processing Events

#### Using the SQS Adapter

The SQS adapter provides methods to interact with SQS:

```ruby
# Receive messages from SQS
messages = CleverEvents::Adapters::SqsAdapter.receive_messages(
  queue_url: "custom-queue-url", # Optional, defaults to configured queue
  max_number_of_messages: 10,     # Optional, defaults to configured batch size
  wait_time_seconds: 10           # Optional, defaults to 0
)

# Delete a single message
CleverEvents::Adapters::SqsAdapter.delete_message(
  message: sqs_message,
  queue_url: "custom-queue-url"   # Optional, defaults to configured queue
)

# Delete multiple messages in batches
CleverEvents::Adapters::SqsAdapter.delete_messages(
  messages: sqs_messages,
  queue_url: "custom-queue-url"   # Optional, defaults to configured queue
)

# Process messages with a processor class
CleverEvents::Adapters::SqsAdapter.process_messages(
  messages: sqs_messages,
  processor_class: MyProcessor,
  queue_url: "custom-queue-url"   # Optional, defaults to configured queue
)

# Send a message to SQS (useful for DLQ scenarios)
CleverEvents::Adapters::SqsAdapter.send_message(
  queue_url: "queue-url",
  message_body: "message body",
  message_attributes: { ... }
)
```

#### Creating Custom Message Processors

Create custom processors by extending the `CleverEvents::Processor` base class:

```ruby
class MyMessageProcessor < CleverEvents::Processor
  def process_message
    # Access the message via the message attribute
    data = JSON.parse(message.body)

    # Process your message here
    MyModel.create!(data: data)

    # Return true if processing succeeded
    true
  rescue StandardError => e
    # You can handle errors here if needed
    Rails.logger.error("Custom processing error: #{e.message}")

    # Re-raise if you want the processor to handle retry logic
    raise e
  end
end
```

Then use your processor:

```ruby
# Process a single message
MyMessageProcessor.process(sqs_message, queue_url: "queue-url")

# Process multiple messages
messages.each do |msg|
  MyMessageProcessor.process(msg, queue_url: "queue-url")
end

# Or use the adapter's process_messages method
CleverEvents::Adapters::SqsAdapter.process_messages(
  messages: messages,
  processor_class: MyMessageProcessor
)
```

#### Automatic Retry and Dead Letter Queue (DLQ) Handling

The processor base class provides automatic handling for:

1. Processing errors with SQS's native retry mechanism
2. Moving messages to a Dead Letter Queue (DLQ) after max retries
3. Error logging and tracking

When a message fails processing:

- If the retry count is below the maximum (controlled by SQS redrive policy),
  the error is re-raised, which returns the message to SQS for retry
- If the retry count exceeds the maximum and a DLQ is configured,
  the message is sent to the DLQ with error details
- If no DLQ is configured, a warning is logged

The message sent to the DLQ includes additional attributes:

```ruby
{
  "original_queue" => { data_type: "String", string_value: original_queue_url },
  "failure_reason" => { data_type: "String", string_value: error_message },
  "retry_count" => { data_type: "Number", string_value: retry_count },
  "failed_at" => { data_type: "String", string_value: timestamp }
}
```

#### Using Background Jobs

For Rails applications, use ActiveJob to process messages in the background:

```ruby
class SqsMessageProcessorJob < ApplicationJob
  queue_as :default

  def perform
    messages = CleverEvents::Adapters::SqsAdapter.receive_messages

    CleverEvents::Adapters::SqsAdapter.process_messages(
      messages: messages,
      processor_class: MyMessageProcessor
    )
  end
end
```

### Message Format

Events are published in the following format:

```json
{
  "event_name": "user.updated",
  "entity_type": "user",
  "entity_id": "123",
  "path": "http://localhost:3000/api/users/123",
  "message_attributes": {
    "event_name": {
      "data_type": "String",
      "string_value": "user.updated"
    },
    "entity_type": {
      "data_type": "String",
      "string_value": "user"
    },
    "entity_id": {
      "data_type": "String",
      "string_value": "123"
    }
  }
}
```

### Error Handling

The gem provides error handling for:

- Invalid topic or queue configuration
- SNS publishing failures
- SQS processing failures
- Invalid message formats
- DLQ handling errors

Errors are logged and raised as `CleverEvents::Error` instances.

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and the created tag, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/clever/clever_events_rails. This project is intended to be a safe, welcoming space for collaboration, and contributors are expected to adhere to the [code of conduct](https://github.com/clever/clever_events_rails/blob/main/CODE_OF_CONDUCT.md).

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).

## Code of Conduct

Everyone interacting in the CleverEventsRails project's codebases, issue trackers, chat rooms and mailing lists is expected to follow the [code of conduct](https://github.com/clever/clever_events_rails/blob/main/CODE_OF_CONDUCT.md).
