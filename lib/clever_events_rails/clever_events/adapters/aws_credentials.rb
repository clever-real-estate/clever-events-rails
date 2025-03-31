# frozen_string_literal: true

module CleverEvents
  module Adapters
    class AwsCredentials
      def region
        CleverEvents.configuration.aws_region
      end

      def access_key_id
        CleverEvents.configuration.aws_access_key_id
      end

      def secret_access_key
        CleverEvents.configuration.aws_secret_access_key
      end
    end
  end
end
