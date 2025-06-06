# CleverEventsRails Changelog

## [Unreleased]

## [0.8.0] - 2025-06-06

### Features

- Added support for custom topic ARN specification per class and instance
- Added ability to publish events when objects are destroyed

### Changes

- Code quality improvements including removal of inline comments
- Enhanced test structure with suppress blocks for error-raising tests
- Updated documentation to remove deprecated DLQ configuration references
- Updated .gitignore file

## [0.7.0] - 2025-05-06

### Changes

- Refactored SQS message handling to leverage native AWS retry functionality
- Removed custom dead letter queue (DLQ) handling since AWS SQS handles this automatically
- Added message processor architecture for better control of message lifecycle
- Enhanced logging to track retry counts for failed messages
- Improved error handling and robustness for SQS message processing

## [0.6.1] - 2025-04-17

### Changes

- Fixed message group ID error by only sending message_group_id when using FIFO topics
- Added ability to skip publishing via skip_publish instance variable on publishable objects
- Documentation improvements
- Dependencies updated (sqlite3 2.5.0 to 2.6.0)

## [0.6.0] - 2025-04-08

### Features

- Added SQS adapter for message subscription functionality
- Implemented message attributes for SNS/SQS
- Added support for FIFO queues
- Added configuration for base API URL in message path parameters
- Enhanced message handling capabilities

## [0.5.0] - 2025-02-27

### Changes

- Removed after_commit callback from included concern
- Allow clients to configure their own callbacks for more flexibility
- Added Dependabot configuration for automated dependency updates

## [0.4.0] - 2025-02-25

### Features

- Updated SNS adapter to match message format expected by SNS
- Added message_group_id and message_deduplication_id parameters for SNS
- Added VCR and WebMock for HTTP interaction testing
- Updated dummy app to include full testing stack

## [0.3.0] - 2025-02-20

### Features

- Added configuration class to CleverEventsRails gem
- Implemented configurable adapter selection
- Updated README with configuration documentation
- Cleaned up dependencies

## [0.2.0] - 2025-02-18

### Changes

- Refactored classes to allow for event_name to be automatically determined
- Changed publish_event method signature for better usability
- Improved overall library interface

## [0.1.0] - 2025-02-12

### Features

- Initial release
- Basic SNS event publishing functionality
- Publishable concern for ActiveRecord models
- Event structure and formatting
