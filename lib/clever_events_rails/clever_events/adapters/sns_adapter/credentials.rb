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
          ENV["AWS_ACCESS_KEY_ID"]
        end

        def secret_access_key
          ENV["AWS_SECRET_ACCESS_KEY"]
        end

        def region
          ENV["AWS_REGION"] || "us-east-1"
        end
      end
    end
  end
end
