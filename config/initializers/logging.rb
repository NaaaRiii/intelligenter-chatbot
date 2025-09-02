# frozen_string_literal: true

# ログフォーマットをカスタマイズ
Rails.application.configure do
  if Rails.env.development? || Rails.env.test?
    # 開発環境とテスト環境でより詳細なログを出力
    config.log_level = :debug
    
    # タグ付きログを有効化
    config.log_tags = [:request_id]
    
    # ログフォーマッターをカスタマイズ
    config.logger = ActiveSupport::TaggedLogging.new(
      ActiveSupport::Logger.new(STDOUT)
    )
    
    # 色付きログを有効化
    config.colorize_logging = true
    
    # チャット関連のログを別ファイルに出力（オプション）
    if ENV['SEPARATE_CHAT_LOG'] == 'true'
      chat_logger = ActiveSupport::Logger.new(
        Rails.root.join('log', "chat_#{Rails.env}.log")
      )
      chat_logger.formatter = Logger::Formatter.new
      
      # チャット専用ロガーを定義
      Rails.application.config.chat_logger = ActiveSupport::TaggedLogging.new(chat_logger)
    end
  end
end

# ActionCableのログレベルを設定
ActionCable.server.config.logger = Rails.logger if defined?(ActionCable)

# ActiveJobのログを詳細化
ActiveJob::Base.logger = Rails.logger