# frozen_string_literal: true

# 複数の会話を一括で分析するワーカー
class BatchAnalysisWorker
  include Sidekiq::Worker

  sidekiq_options queue: 'low',
                  retry: 3,
                  backtrace: 5

  def perform(conversation_ids, options = {})
    Rails.logger.info "Starting batch analysis for #{conversation_ids.size} conversations"

    results = []
    failed_ids = []

    conversation_ids.each do |conversation_id|
      # 個別の分析ワーカーを非同期で実行
      ConversationAnalysisWorker.perform_async(conversation_id, options)
      results << { conversation_id: conversation_id, status: 'queued' }
    rescue StandardError => e
      Rails.logger.error "Failed to queue analysis for conversation ##{conversation_id}: #{e.message}"
      failed_ids << conversation_id
    end

    # バッチ処理の結果をログに記録
    Rails.logger.info "Batch analysis queued: #{results.size} successful, #{failed_ids.size} failed"

    {
      total: conversation_ids.size,
      queued: results.size,
      failed: failed_ids
    }
  end
end