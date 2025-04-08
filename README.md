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
  config.publish_events = true
  config.sns_topic_arn = "arn:aws:sns:region:account-id:topic-name"
  config.sqs_queue_url = "https://sqs.region.amazonaws.com/account-id/queue-name"
  config.aws_access_key_id = "your-access-key"
  config.aws_secret_access_key = "your-secret-key"
  config.aws_region = "us-east-1"
  config.base_api_url = "http://localhost:3000/api"
  config.fifo_topic = true # Set to true if using FIFO topics
end
```

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

Process events from SQS:

```ruby
CleverEvents::Subscriber.receive_messages
```

This will:

1. Receive messages from SQS
2. Process each message
3. Delete processed messages from the queue
4. Log processing results

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

- Invalid topic configuration
- SNS publishing failures
- SQS processing failures
- Invalid message formats

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
