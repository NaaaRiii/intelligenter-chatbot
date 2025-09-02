source 'https://rubygems.org'
git_source(:github) { |repo| "https://github.com/#{repo}.git" }

ruby '3.2.8'

# Rails本体
gem 'rails', '~> 8.0.2'

# データベース
gem 'pg', '~> 1.5'
gem 'pgvector', '~> 0.2'

# Webサーバー
gem 'puma', '~> 6.0'

# Redis & 非同期処理
gem 'redis', '~> 5.0'
gem 'sidekiq', '~> 7.0'

# ActionCable (Railsに含まれる)

# フロントエンド統合
gem 'vite_rails', '~> 3.0'

# API
gem 'jbuilder'
gem 'rack-cors'

# AI・外部API
gem 'httparty', '~> 0.21' # HTTP クライアント
gem 'ruby-anthropic', '~> 0.4.2' # Claude API クライアント
gem 'ruby-openai', '~> 6.3' # OpenAI API クライアント

# GraphQL
gem 'graphiql-rails', '~> 1.9', group: :development
gem 'graphql', '~> 2.2'

# Pagination
gem 'kaminari', '~> 1.2'

# その他
gem 'bootsnap', '>= 1.4.4', require: false
gem 'tzinfo-data', platforms: %i[mingw mswin x64_mingw jruby]

group :development, :test do
  # デバッグ
  gem 'debug', platforms: %i[mri mingw x64_mingw]
  gem 'pry-byebug'
  gem 'pry-rails'

  # テスト
  gem 'factory_bot_rails'
  gem 'faker'
  gem 'rspec-rails', '~> 6.0'
  gem 'shoulda-matchers'

  # コード品質
  gem 'rubocop', require: false
  gem 'rubocop-rails', require: false
  gem 'rubocop-rspec', require: false
  gem 'rubocop-performance', require: false
end

group :development do
  # 開発効率化
  gem 'listen', '~> 3.3'
  gem 'spring'

  # パフォーマンス
  gem 'bullet'
  gem 'rack-mini-profiler'
end

group :test do
  # テストカバレッジ
  gem 'simplecov', require: false
  gem 'simplecov-cobertura', require: false

  # テスト結果フォーマッター
  gem 'rspec_junit_formatter'

  # システムテスト
  gem 'capybara'
  gem 'selenium-webdriver'

  # API テスト
  gem 'vcr'
  gem 'webmock'

  # DBクリーナー
  gem 'database_cleaner-active_record'
end
