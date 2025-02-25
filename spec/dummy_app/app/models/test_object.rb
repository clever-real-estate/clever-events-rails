# frozen_string_literal: true

class TestObject < ActiveRecord::Base
  include CleverEvents::Publishable

  validates :first_name, presence: true

  publishable_attrs :first_name, :last_name, :email, :phone
  publishable_actions :updated
end
