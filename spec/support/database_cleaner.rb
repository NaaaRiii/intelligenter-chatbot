# frozen_string_literal: true

require 'database_cleaner/active_record'

RSpec.configure do |config|
  config.before(:suite) do
    # テスト開始前にデータベースをクリーンにする
    DatabaseCleaner.clean_with(:deletion)
  end

  config.before do |example|
    # System specs以外はトランザクションを使用
    if example.metadata[:type] == :system || example.metadata[:js]
      DatabaseCleaner.strategy = :deletion
    else
      DatabaseCleaner.strategy = :transaction
    end
    DatabaseCleaner.start
  end

  config.after do
    DatabaseCleaner.clean
  end

  config.append_after do
    # 各テスト後にデータベース接続をリセット
    ActiveRecord::Base.connection_pool.disconnect!
  end
end