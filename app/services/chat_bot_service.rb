# frozen_string_literal: true

# チャットボットの応答生成サービス
class ChatBotService
  include ActiveModel::Model

  attr_accessor :conversation, :user_message, :context

  validates :conversation, presence: true
  validates :user_message, presence: true

  # 応答タイプの定義
  RESPONSE_TYPES = {
    greeting: 'greeting',
    question: 'question',
    complaint: 'complaint',
    feedback: 'feedback',
    general: 'general'
  }.freeze

  def initialize(conversation:, user_message:, context: {})
    @conversation = conversation
    @user_message = user_message
    @context = context
    @rag_service = RagService.new
    @context_injection_service = ContextInjectionService.new
    @claude_service = ClaudeApiService.new
  end

  # ボット応答を生成
  def generate_response # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
    return nil unless valid?

    intent = recognize_intent
    response_content = build_response(intent)

    # 応答メッセージを作成
    bot_message = conversation.messages.build(
      content: response_content,
      role: 'assistant',
      metadata: {
        intent: intent[:type],
        confidence: intent[:confidence],
        template_used: intent[:template_id]
      }
    )

    if bot_message.save
      broadcast_response(bot_message)
      bot_message
    else
      errors.add(:base, 'ボット応答の保存に失敗しました')
      nil
    end
  rescue StandardError => e
    Rails.logger.error "Bot response generation failed: #{e.message}"
    errors.add(:base, 'システムエラーが発生しました')
    nil
  end

  # 非同期でボット応答を生成
  def generate_response_async?
    return false unless valid?

    BotResponseJob.perform_later(
      conversation_id: conversation.id,
      user_message_id: user_message.id
    )
    true
  end

  # RAGを活用した応答生成
  def generate_response_with_rag
    return nil unless valid?

    # 1. RAGパイプラインでコンテキスト取得
    rag_result = @rag_service.rag_pipeline(@user_message, conversation: @conversation)
    
    # 2. FAQ、事例、製品情報を注入
    enriched_context = @context_injection_service.inject_context(@user_message, conversation: @conversation)
    
    # 3. 統合コンテキストを構築
    combined_context = {
      rag_context: rag_result[:context],
      faqs: enriched_context[:faqs],
      case_studies: enriched_context[:case_studies],
      product_info: enriched_context[:product_info]
    }
    
    # 4. 会話履歴を準備
    conversation_history = prepare_conversation_history
    
    # 5. Claude APIに拡張コンテキストと共に送信
    response_content = @claude_service.generate_response_with_context(
      conversation_history,
      @user_message,
      combined_context
    )
    
    # 6. 応答メッセージを作成・保存
    bot_message = save_bot_message(response_content, rag_result)
    
    if bot_message
      broadcast_response(bot_message)
      bot_message
    else
      errors.add(:base, 'ボット応答の保存に失敗しました')
      nil
    end
  rescue StandardError => e
    Rails.logger.error "RAG-enhanced response generation failed: #{e.message}"
    # RAGなしでフォールバック
    generate_response
  end

  private

  # 意図を認識
  def recognize_intent
    analyzer = IntentRecognizer.new(message: user_message.content)
    intent_result = analyzer.recognize

    {
      type: intent_result[:type] || RESPONSE_TYPES[:general],
      confidence: intent_result[:confidence] || 0.5,
      keywords: intent_result[:keywords] || [],
      template_id: nil
    }
  end

  # 応答を構築
  def build_response(intent)
    template_manager = ResponseTemplates.new(
      intent_type: intent[:type],
      context: build_context(intent)
    )

    response = template_manager.response
    intent[:template_id] = template_manager.template_id

    response
  end

  # コンテキストを構築
  def build_context(intent)
    {
      user_name: context[:user_name] || 'お客様',
      conversation_id: conversation.id,
      message_count: conversation.messages.count,
      intent_keywords: intent[:keywords],
      previous_messages: recent_messages,
      time_of_day: greeting_time
    }
  end

  # 最近のメッセージを取得
  def recent_messages
    conversation.messages
                .latest_n(5)
                .pluck(:content, :role)
                .map { |content, role| { content: content, role: role } }
  end

  # 時間帯に応じた挨拶
  def greeting_time
    hour = Time.current.hour
    case hour
    when 5..10 then 'morning'
    when 11..17 then 'afternoon'
    when 18..22 then 'evening'
    else 'night'
    end
  end

  # WebSocketで応答を配信
  def broadcast_response(bot_message)
    ActionCable.server.broadcast(
      "conversation_#{conversation.id}",
      {
        type: 'bot_response',
        message: {
          id: bot_message.id,
          content: bot_message.content,
          role: bot_message.role,
          created_at: bot_message.created_at,
          metadata: bot_message.metadata
        }
      }
    )
  end

  # 会話履歴を準備
  def prepare_conversation_history
    conversation.messages
                .order(:created_at)
                .limit(10)
                .map { |msg| { role: msg.role, content: msg.content } }
  end

  # ボットメッセージを保存
  def save_bot_message(response_content, rag_result = nil)
    metadata = {
      rag_used: rag_result.present?,
      sources_count: rag_result&.dig(:context, :retrieved_messages)&.size || 0,
      confidence_score: rag_result&.dig(:response, :confidence_score),
      performance_metrics: rag_result&.dig(:performance_metrics)
    }

    conversation.messages.create(
      content: response_content,
      role: 'assistant',
      metadata: metadata
    )
  end
end
