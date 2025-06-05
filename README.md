# CleverEventsRails

A Rails engine for publishing and processing events using AWS SNS and SQS.

## Installation

Add this line to your application's Gemfile:

```ruby
gem "clever_events_rails"
```

And then execute:

```bash
bundle install
```

Or install it yourself as:

```bash
gem install clever_events_rails
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

#### Custom Topic ARNs

You can specify custom topic ARNs for different models or instances:

##### Class-level Custom Topic ARN

Configure a custom topic ARN for all instances of a model:

```ruby
class User < ApplicationRecord
  include CleverEvents::Publishable

  publishable_attrs :name, :email
  publishable_actions :create, :update, :destroy
  publishable_topic_arn "arn:aws:sns:us-east-1:123456789012:user-events"
end

class Order < ApplicationRecord
  include CleverEvents::Publishable

  publishable_attrs :status, :total
  publishable_actions :create, :update
  publishable_topic_arn "arn:aws:sns:us-east-1:123456789012:order-events"
end
```

##### Instance-level Custom Topic ARN

Override the topic ARN for specific instances:

```ruby
user = User.new(name: "John", email: "john@example.com")
user.topic_arn = "arn:aws:sns:us-east-1:123456789012:vip-user-events"
user.save! # Will publish to the VIP topic instead of the default or class-level topic

# Reset to use class-level or default topic
user.topic_arn = nil
user.update!(name: "John Doe") # Will use class-level or default topic
```

##### Topic ARN Priority

The system uses the following priority order for determining which topic ARN to use:

1. **Instance-level** `topic_arn` (highest priority)
2. **Class-level** `publishable_topic_arn`
3. **Global default** from configuration (`config.sns_topic_arn`)

If none are set, the system will raise an error.

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
  receipt_handle: sqs_message.receipt_handle,
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

# Send a message to SQS
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

#### Automatic Retry Handling

The processor relies on AWS SQS's native retry functionality:

1. When a message fails processing in your application:

   - The processor logs the error and re-raises it
   - SQS's built-in retry mechanism handles returning the message to the queue
   - The message becomes available again after the visibility timeout

2. You can track the number of processing attempts:

   - Each message includes an `ApproximateReceiveCount` attribute
   - The processor logs this value when errors occur

3. To configure SQS retry behavior:
   - Adjust the visibility timeout on your SQS queue
   - This determines how long a message is hidden after being received
   - For example, a 30-second timeout gives your processor 30 seconds to complete

This approach leverages AWS SQS's built-in reliability features for handling retries.

#### Using Background Jobs

For Rails applications, use ActiveJob to process messages in the background:

```ruby
class SqsMessageProcessorJob < ApplicationJob
  queue_as :default

  def perform
    messages = CleverEvents::Subscriber.receive_messages

    messages.each do |message|
      begin
        process_message(message)
        CleverEvents::Adapters::SqsAdapter.delete_message(
          receipt_handle: message.receipt_handle
        )
      rescue StandardError => e
        Rails.logger.error("Failed to process message: #{e.class} - #{e.message}")
      end
    end
  end

  private

  def process_message(message)
    data = JSON.parse(message.body)
    Rails.logger.info("Processing message: #{data}")
    # Your custom processing logic here
  end
end
```

Set up a scheduler to run this job periodically:

```ruby
# Use a gem like sidekiq-scheduler or whenever to schedule this
SqsMessageProcessorJob.perform_later
```

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and the created tag, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at <https://github.com/clever/clever_events_rails>. This project is intended to be a safe, welcoming space for collaboration, and contributors are expected to adhere to the [code of conduct](https://github.com/clever/clever_events_rails/blob/main/CODE_OF_CONDUCT.md).

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).

## Code of Conduct

Everyone interacting in the CleverEventsRails project's codebases, issue trackers, chat rooms and mailing lists is expected to follow the [code of conduct](https://github.com/clever/clever_events_rails/blob/main/CODE_OF_CONDUCT.md).
