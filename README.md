# CleverEventsRails
## Installation

Add the gem to your gemfile:
```ruby
gem "clever_events_rails", "~> 0.3.0", git: "https://github.com/clever-real-estate/clever-events-rails"
```

```
bundle install
```

## Configuration
You will need to configure this gem via a configuration block. When using rails, this typically can go in an initializer:
```ruby
# config/initializers/clever_events.rb
CleverEvents.configure do |config|
  config.publish_events = false # set this to true to send events to whatever adapter
  config.events_adapter = :sns #this is the default
  config.aws_access_key_id = "my_access_key_id"
  config.aws_secret_access_key = "super_duper_secret"
  config.aws_region = "us-east-1"
end
```
>Note: setting `publish_events` to some configuration your app uses will probably be your best bet, Either a custom config from an environment file or an env var

## Usage
You can include the gem's module in the model you want to publish events from:

```ruby
class Object < ApplicationRecord
  include CleverEvents::Publishable
  ...
end
```

Simply including the `Publishable` module it will give access to a few methods:
- `publishable_attrs` is a class attribute, that accepts an array of symbols corresponding to the attributes we want to send events about (updates only).
- `publishable_actions` is another class attribute that accepts an array of symbols, corresponding to the _actions_ that the object undergoes. If this is not explicitly added, the defaults are `[:create, :update, :destroy]`.
- `#publish_event` is automatically included. It synchrounously publishes an event via the adapter specified.

If you want to implement your own `#publish_event` method, just implement it in the model:
```ruby
def publish_event!
  SomeEventPublisherJob.perform_later(event_name, self) # or whatever implementation you want
end
```
> Note: `event_name` is a method included in whatever class includes CleverEvents::Publisher, which outputs a name in the structure of `object_class.action`, ex: `TestObject.updated`.

And then make sure your implementation eventually calls `.publish_event!` (make sure you include the `CleverEvents::Publisher` module to have access to `.publish_event!` wherever you call it from):
```ruby
class SomeEventPublisherJob
  include CleverEvents::Publishaer

  def perform_later(event_name, object)
    CleverEvents::Publisher.publish_event!(event_name, object)
  end
end
```

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`.

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/clever-real-estate/clever_events_rails.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
