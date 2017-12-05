# frozen_string_literal: true

require 'rspec'
require 'vcr'
require 'simplecov'
require 'dotenv'
require 'env_vars/dotenv'
require 'timecop'

# Load environment
require_relative '../lib/config'

# SimpleCov.formatter = SimpleCov::Formatter::HTMLFormatter
SimpleCov.start

VCR.configure do |config|
  config.ignore_localhost = true
  config.cassette_library_dir = 'spec/fixtures/vcr_cassettes'
  config.configure_rspec_metadata!
  config.hook_into :webmock

  config.allow_http_connections_when_no_cassette = true

  config.default_cassette_options = {
    record: :new_episodes
  }

  config.debug_logger = File.open('log/vcr.log', 'w') if ENV.key? 'VCR_DEBUG'
end

RSpec.configure do |config|
  config.order = :random

  # Add VCR to all tests
  config.around(:each) do |example|
    use_vcr = example.metadata[:vcr]

    if use_vcr
      name = example.metadata[:full_description]
                    .split(/\s+/, 2)
                    .join('/')
                    .tr('.', '/')
                    .gsub(%r{[^\w\/]+}, '_')
                    .gsub(%r{\/$}, '')

      VCR.use_cassette(name, {}, &example)
    else
      WebMock.allow_net_connect!
      VCR.turn_off!
      example.call
      VCR.turn_on!
    end
  end
end
