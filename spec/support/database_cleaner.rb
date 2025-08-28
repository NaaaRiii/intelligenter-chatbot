# frozen_string_literal: true

require 'database_cleaner/active_record'

RSpec.configure do |config|
  # system specやJS実行時はトランザクションが跨がるため、全体としてトランザクションは無効
  config.use_transactional_fixtures = false

  config.before(:suite) do
    DatabaseCleaner.clean_with(:truncation)
  end

  # デフォルトは高速なトランザクション
  config.before(:each) do
    DatabaseCleaner.strategy = :transaction
  end

  # JS実行のテストは別プロセスとなるためトランケーション
  config.before(:each, js: true) do
    DatabaseCleaner.strategy = :truncation
  end

  # system spec はドライバに関わらずトランケーションで安定化
  config.before(:each, type: :system) do
    DatabaseCleaner.strategy = :truncation
  end

  config.before(:each) do
    DatabaseCleaner.start
  end

  config.append_after(:each) do
    DatabaseCleaner.clean
  end
end

 
