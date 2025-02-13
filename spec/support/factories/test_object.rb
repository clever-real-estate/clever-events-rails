# frozen_string_literal: true

FactoryBot.define do
  factory :test_object do
    sequence(:first_name) { |n| "Test Object #{n}" }
    sequence(:last_name) { |n| "Last Name #{n}" }
  end
end
