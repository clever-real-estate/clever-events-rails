# frozen_string_literal: true

require_relative "lib/clever_events_rails/version"

Gem::Specification.new do |spec|
  spec.name = "clever_events_rails"
  spec.version = CleverEventsRails::VERSION
  spec.authors = ["Nick Clucas"]
  spec.email = ["nick@gravy.co"]

  spec.summary = "Smart event pub/sub for rails apps"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.1.0"

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  gemspec = File.basename(__FILE__)
  spec.files = IO.popen(%w[git ls-files -z], chdir: __dir__, err: IO::NULL) do |ls|
    ls.readlines("\x0", chomp: true).reject do |f|
      (f == gemspec) ||
        f.start_with?(*%w[bin/ test/ spec/ features/ .git .github appveyor Gemfile])
    end
  end
  spec.bindir = "exe"
  spec.executables = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_development_dependency "activejob"
  spec.add_development_dependency "appraisal"
  spec.add_development_dependency "dotenv"
  spec.add_development_dependency "factory_bot"
  spec.add_development_dependency "pry"
  spec.add_development_dependency "pry-byebug"
  spec.add_development_dependency "rails"
  spec.add_development_dependency "rake"
  spec.add_development_dependency "rspec"
  spec.add_development_dependency "rspec-rails"
  spec.add_development_dependency "rubocop"
  spec.add_development_dependency "rubocop-factory_bot"
  spec.add_development_dependency "rubocop-rails"
  spec.add_development_dependency "rubocop-rake"
  spec.add_development_dependency "rubocop-rspec"
  spec.add_development_dependency "rubocop-rspec_rails"
  spec.add_development_dependency "simplecov"
  spec.add_development_dependency "simplecov-cobertura"
  spec.add_development_dependency "sqlite3"
  spec.add_development_dependency "vcr"
  spec.add_development_dependency "webmock"

  spec.add_runtime_dependency "activesupport"
  spec.add_runtime_dependency "aws-sdk-sns"
  spec.add_runtime_dependency "aws-sdk-sqs"
  spec.add_runtime_dependency "railties", ">= 4.1"
end
