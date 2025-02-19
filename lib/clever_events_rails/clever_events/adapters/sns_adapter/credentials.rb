# frozen_string_literal: true

module CleverEvents
  module Adapters
    module SnsAdapter
      class Credentials
        def initialize
          @access_key_id = access_key_id
          @secret_access_key = secret_access_key
          @region = region
        end

        def access_key_id
          CleverEvents.configuration.aws_access_key_id
        end

        def secret_access_key
          CleverEvents.configuration.aws_secret_access_key
        end

        def region
          CleverEvents.configuration.aws_region
        end
      end
    end
  end
end
