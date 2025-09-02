# frozen_string_literal: true

# フィーチャーフラグの設定
Rails.application.configure do
  # RAG（Retrieval-Augmented Generation）機能の有効/無効
  # 環境変数で制御、デフォルトは無効（安全側）
  config.rag_enabled = ENV.fetch('RAG_ENABLED', 'false') == 'true'
  
  # Embedding生成機能の有効/無効
  # 環境変数で制御、デフォルトは無効（API課金を避けるため）
  config.embedding_enabled = ENV.fetch('EMBEDDING_ENABLED', 'false') == 'true'
  
  # 開発環境とテスト環境ではデフォルトで有効化することも可能
  if Rails.env.development? || Rails.env.test?
    config.rag_enabled = ENV.fetch('RAG_ENABLED', 'true') == 'true'
    # embedding生成はテスト環境でのみデフォルト有効（モック使用）
    config.embedding_enabled = ENV.fetch('EMBEDDING_ENABLED', Rails.env.test? ? 'true' : 'false') == 'true'
  end
  
  # ログ出力
  Rails.logger.info "RAG機能: #{config.rag_enabled ? '有効' : '無効'}"
  Rails.logger.info "Embedding生成: #{config.embedding_enabled ? '有効' : '無効'}"
end