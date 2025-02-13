# frozen_string_literal: true

module RouteHelpers
  # @!method get
  # @!method post
  # @!method put
  # @!method patch
  # @!method delete
  # @!method options
  # @!method head
  #
  # Shorthand method for matching this type of route.
  %w[get post put patch delete options head].each do |method|
    define_method method do |path|
      { method.to_sym => path }
    end
  end
end

RSpec.configure do |config|
  config.include RouteHelpers, type: :request
end
