# frozen_string_literal: true

require 'database_cleaner/active_record'

RSpec.configure do |config|
  config.before(:suite) do
    # テスト開始前にデータベースをクリーンにする
    DatabaseCleaner.clean_with(:deletion)
  end

  config.before do |example|
    # System specs以外はトランザクションを使用
    DatabaseCleaner.strategy = if example.metadata[:type] == :system || example.metadata[:js]
                                 :deletion
                               else
                                 :transaction
                               end
    DatabaseCleaner.start
  end

  config.after do
    DatabaseCleaner.clean
  end

  # 各テスト後のクリーンアップは DatabaseCleaner.clean で行う
end
