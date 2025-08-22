# frozen_string_literal: true

require 'database_cleaner/active_record'

RSpec.configure do |config|
  # System specsではトランザクションを使わない
  config.use_transactional_fixtures = false

  config.before(:suite) do
    DatabaseCleaner.clean_with(:truncation)
  end

  config.before do |example|
    DatabaseCleaner.strategy = example.metadata[:js] ? :truncation : :transaction
    DatabaseCleaner.start
  end

  config.after do
    DatabaseCleaner.clean
  end

  config.before(:each, type: :system) do
    DatabaseCleaner.strategy = :truncation
  end
end
