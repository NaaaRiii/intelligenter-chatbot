# frozen_string_literal: true

require 'webmock/rspec'

# Allow Capybara's local server health checks while blocking external calls
WebMock.disable_net_connect!(allow_localhost: true)

# Prevent ENV leakage across examples that affects notification behaviors
RSpec.configure do |config|
  config.around(:each) do |example|
    original_slack = ENV['SLACK_WEBHOOK_URL']
    begin
      # Default to nil unless each example deliberately sets it
      ENV['SLACK_WEBHOOK_URL'] = nil
      example.run
    ensure
      ENV['SLACK_WEBHOOK_URL'] = original_slack
    end
  end
end


