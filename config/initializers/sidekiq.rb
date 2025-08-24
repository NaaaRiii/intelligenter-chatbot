# frozen_string_literal: true

# Sidekiq設定
require 'sidekiq'

# Redis接続設定
redis_config = {
  url: ENV.fetch('REDIS_URL', 'redis://localhost:6379/0'),
  network_timeout: 5,
  pool_timeout: 5
}

# Sidekiqサーバー設定
Sidekiq.configure_server do |config|
  config.redis = redis_config

  # ログフォーマット設定
  config.logger.level = Rails.env.production? ? Logger::INFO : Logger::DEBUG

  # エラーハンドリング
  config.error_handlers << proc do |exception, context_hash|
    Rails.logger.error "Sidekiq error: #{exception.class}: #{exception.message}"
    Rails.logger.error exception.backtrace.join("\n") if exception.backtrace
    Rails.logger.error "Context: #{context_hash.inspect}"
  end

  # サーバーミドルウェア
  config.server_middleware do |chain|
    # タイムアウト設定
    # chain.add Sidekiq::Middleware::Server::Timeout
  end

  # デスキュー設定
  config.death_handlers << ->(job, _ex) do
    Rails.logger.error "Job died: #{job['class']} with args #{job['args']}"
  end
end

# Sidekiqクライアント設定
Sidekiq.configure_client do |config|
  config.redis = redis_config

  # クライアントミドルウェア
  config.client_middleware do |chain|
    # 必要に応じてミドルウェアを追加
  end
end

# ActiveJobアダプター設定
Rails.application.config.active_job.queue_adapter = :sidekiq if defined?(Rails)

# Sidekiqのデフォルトオプション
Sidekiq.default_job_options = {
  'retry' => 3,
  'backtrace' => true,
  'queue' => 'default'
}

# 分析ジョブ用の設定
module SidekiqJobOptions
  ANALYSIS_JOB_OPTIONS = {
    'queue' => 'analysis',
    'retry' => 5,
    'backtrace' => 10,
    'dead' => true
  }.freeze

  CRITICAL_JOB_OPTIONS = {
    'queue' => 'critical',
    'retry' => 10,
    'backtrace' => 20
  }.freeze

  LOW_PRIORITY_OPTIONS = {
    'queue' => 'low',
    'retry' => 2,
    'backtrace' => 5
  }.freeze
end