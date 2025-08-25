# frozen_string_literal: true

# 会話分析を非同期で実行するワーカー
class ConversationAnalysisWorker
  include Sidekiq::Worker

  sidekiq_options queue: 'analysis',
                  retry: 5,
                  backtrace: 10,
                  dead: true

  # リトライ時の待機時間を指数関数的に増やす
  sidekiq_retry_in do |count, exception|
    case exception
    when Net::OpenTimeout, Net::ReadTimeout
      # API タイムアウトの場合は少し長めに待つ
      (count**2) * 30
    else
      # その他のエラーは通常の待機時間
      (count**2) * 10
    end
  end

  def perform(conversation_id, options = {})
    Rails.logger.info "Starting analysis for conversation ##{conversation_id}"

    conversation = Conversation.find(conversation_id)
    
    # 分析サービスの実行
    result = if options['use_storage']
               # ストレージサービスを使用（感情分析 + DB保存）
               storage_service = AnalysisStorageService.new(conversation)
               storage_service.store_analysis
             else
               # 通常の分析のみ
               analyzer = SentimentAnalyzer.new
               messages = prepare_messages(conversation)
               analyzer.analyze_conversation(messages)
             end

    # 分析完了をブロードキャスト
    broadcast_analysis_complete(conversation, result)

    Rails.logger.info "Completed analysis for conversation ##{conversation_id}"
    result
  rescue ActiveRecord::RecordNotFound => e
    Rails.logger.error "Conversation not found: #{e.message}"
    raise # Sidekiqがリトライしないようにする
  rescue StandardError => e
    Rails.logger.error "Analysis failed for conversation ##{conversation_id}: #{e.message}"
    Rails.logger.error e.backtrace.join("\n")
    
    # エラー通知をブロードキャスト
    broadcast_analysis_error(conversation_id, e.message) if conversation_id
    
    raise # Sidekiqにリトライさせる
  end

  private

  def prepare_messages(conversation)
    conversation.messages.order(:created_at).map do |message|
      {
        role: message.role,
        content: message.content,
        created_at: message.created_at
      }
    end
  end

  def broadcast_analysis_complete(conversation, result)
    return unless conversation

    ActionCable.server.broadcast(
      "conversation_#{conversation.id}",
      {
        type: 'analysis_complete',
        conversation_id: conversation.id,
        analysis: format_analysis_result(result),
        timestamp: Time.current.iso8601
      }
    )
  end

  def broadcast_analysis_error(conversation_id, error_message)
    ActionCable.server.broadcast(
      "conversation_#{conversation_id}",
      {
        type: 'analysis_error',
        conversation_id: conversation_id,
        error: error_message,
        timestamp: Time.current.iso8601
      }
    )
  end

  def format_analysis_result(result)
    if result.is_a?(Analysis)
      # Analysisモデルの場合
      {
        id: result.id,
        sentiment: result.sentiment,
        confidence_score: result.confidence_score,
        hidden_needs: result.hidden_needs,
        priority_level: result.priority_level,
        escalated: result.escalated
      }
    else
      # ハッシュ形式の結果の場合
      {
        sentiment: result[:overall_sentiment],
        confidence_score: result.dig(:sentiment_history, 0, :sentiment, :confidence),
        keywords: result[:keyword_insights],
        escalation_required: result[:escalation_required]
      }
    end
  end
end