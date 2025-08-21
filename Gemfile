source "https://rubygems.org"

ruby "3.2.2"

# Rails本体
gem "rails", "~> 7.1.0"

# データベース
gem "pg", "~> 1.5"
gem "pgvector", "~> 0.2"

# Webサーバー
gem "puma", "~> 6.0"

# Redis & 非同期処理
gem "redis", "~> 5.0"
gem "sidekiq", "~> 7.0"

# フロントエンド統合
gem "vite_rails", "~> 3.0"
gem "stimulus-rails"
gem "turbo-rails"

# API
gem "jbuilder"
gem "rack-cors"

# 認証・認可（後で追加予定）
# gem "devise"
# gem "pundit"

# その他
gem "bootsnap", ">= 1.4.4", require: false
gem "tzinfo-data", platforms: %i[ windows jruby ]

group :development, :test do
  # デバッグ
  gem "debug", platforms: %i[ mri windows ]
  gem "pry-rails"
  gem "pry-byebug"
  
  # テスト
  gem "rspec-rails", "~> 6.0"
  gem "factory_bot_rails"
  gem "faker"
  gem "shoulda-matchers"
  
  # コード品質
  gem "rubocop", require: false
  gem "rubocop-rails", require: false
  gem "rubocop-rspec", require: false
end

group :development do
  # 開発効率化
  gem "listen", "~> 3.3"
  gem "spring"
  gem "web-console"
  
  # パフォーマンス
  gem "bullet"
  gem "rack-mini-profiler"
end

group :test do
  # テストカバレッジ
  gem "simplecov", require: false
  
  # システムテスト
  gem "capybara"
  gem "selenium-webdriver"
  gem "webdrivers"
  
  # API テスト
  gem "vcr"
  gem "webmock"
end