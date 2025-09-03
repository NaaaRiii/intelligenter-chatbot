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
    
    # 2-3往復で本分析（ニーズプレビュー更新）
    flags = Rails.configuration.x.needs_preview
    user_turns = conversation.messages.where(role: 'user').count
    if flags.enabled
      needs_preview_missing = conversation.analyses.by_type('needs_preview').blank?
      within_window = user_turns >= flags.turn_threshold_min && user_turns <= flags.turn_threshold_max
      over_window_without_preview = user_turns > flags.turn_threshold_max && needs_preview_missing

      if within_window || over_window_without_preview
        update_needs_preview(conversation)
      end
    end

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
  def update_needs_preview(conversation)
    messages = conversation.messages
                            .order(:created_at)
                            .last(8)
                            .map { |m| { role: m.role, content: m.content } }

    inference = NeedInferenceService.new.infer(messages: messages)

    analysis = conversation.analyses.find_or_initialize_by(analysis_type: 'needs_preview')
    analysis.analysis_data = inference
    analysis.confidence_score = inference['confidence']
    analysis.analyzed_at = Time.current
    analysis.save!

    ConversationChannel.broadcast_to(
      conversation,
      {
        type: 'needs_preview',
        analysis: {
          confidence: analysis.confidence_score,
          category: inference['category'],
          need_type: inference['need_type'],
          keywords: inference['keywords'],
          evidence: inference['evidence']
        }
      }
    )
  rescue StandardError => e
    Rails.logger.warn "[ConversationAnalysisWorker] needs_preview update failed: #{e.message}"
  end

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

    ConversationChannel.broadcast_to(
      conversation,
      {
        type: 'analysis_complete',
        conversation_id: conversation.id,
        analysis: format_analysis_result(result),
        timestamp: Time.current.iso8601
      }
    )
  end

  def broadcast_analysis_error(conversation_id, error_message)
    ConversationChannel.broadcast_to(
      Conversation.find(conversation_id),
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