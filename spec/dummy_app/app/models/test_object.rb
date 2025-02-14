# frozen_string_literal: true

class TestObject < ActiveRecord::Base
  include Events::Publisher

  publishable_attrs :first_name, :last_name, :email, :phone
  publishable_actions :created, :updated, :destroyed
end
