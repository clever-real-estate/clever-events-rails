# frozen_string_literal: true

require "simplecov-cobertura"

SimpleCov.start do
  enable_coverage :branch
  add_filter "/spec/dummy_app/"

  formatter SimpleCov::Formatter::CoberturaFormatter if ENV["CI"]

  SimpleCov.command_name "appraisal-#{ENV["BUNDLE_GEMFILE"]}"
end
