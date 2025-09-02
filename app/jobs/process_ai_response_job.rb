class ProcessAiResponseJob < ApplicationJob
  queue_as :ai_processing

  def perform(message_id)
    Rails.logger.info "="*80
    Rails.logger.info "[PROCESS_AI JOB START] ProcessAiResponseJob#perform"
    Rails.logger.info "Message ID: #{message_id}"
    Rails.logger.info "="*80
    
    message = Message.find(message_id)
    Rails.logger.info "[PROCESS_AI STEP 1] Message loaded: #{message.content}"
    
    unless message&.from_user?
      Rails.logger.warn "[PROCESS_AI WARNING] Not a user message, skipping"
      return
    end

    process_ai_response(message)
    
    Rails.logger.info "[PROCESS_AI JOB END] ProcessAiResponseJob#perform"
    Rails.logger.info "="*80
  rescue StandardError => e
    Rails.logger.error "[PROCESS_AI ERROR] AI Response Error: #{e.message}"
    Rails.logger.error "[PROCESS_AI ERROR] Backtrace: #{e.backtrace.first(5).join("\n")}"
    broadcast_error(message.conversation, e.message) if message
  end

  private

  def process_ai_response(message)
    conversation = message.conversation
    Rails.logger.info "[PROCESS_AI STEP 2] Processing for conversation #{conversation.id}"
    
    ai_response = generate_ai_response(message)
    Rails.logger.info "[PROCESS_AI STEP 3] AI response generated: #{ai_response[:content]&.truncate(200)}"
    
    response_message = create_ai_message(conversation, ai_response)
    Rails.logger.info "[PROCESS_AI STEP 4] Response message created with ID: #{response_message.id}"
    
    broadcast_ai_message(conversation, response_message)
    Rails.logger.info "[PROCESS_AI STEP 5] Response broadcasted"
    
    AnalyzeConversationJob.perform_later(conversation.id)
    Rails.logger.info "[PROCESS_AI STEP 6] Analysis job queued"
  end

  def create_ai_message(conversation, ai_response)
    conversation.messages.create!(
      content: ai_response[:content],
      role: 'assistant',
      metadata: build_ai_metadata(ai_response)
    )
  end

  def build_ai_metadata(ai_response)
    {
      ai_model: 'claude-3',
      processing_time: ai_response[:processing_time],
      confidence: ai_response[:confidence]
    }
  end

  def broadcast_ai_message(conversation, response_message)
    ConversationChannel.broadcast_to(
      conversation,
      build_broadcast_payload(response_message)
    )
  end

  def build_broadcast_payload(response_message)
    {
      type: 'new_message',
      message: {
        id: response_message.id,
        content: response_message.content,
        role: response_message.role,
        created_at: response_message.created_at,
        metadata: response_message.metadata
      }
    }
  end

  def generate_ai_response(message)
    start_time = Time.current
    conversation = message.conversation
    
    Rails.logger.info "[PROCESS_AI GENERATE] Starting AI response generation"
    Rails.logger.info "  - Message: #{message.content}"
    Rails.logger.info "  - Category: #{conversation.metadata&.dig('category')}"

    # ChatBotServiceを使用して実際のAI応答を生成
    bot_service = ChatBotService.new(
      conversation: conversation,
      user_message: message,
      context: {
        user_name: conversation.metadata&.dig('user_name')
      }
    )

    # 直接応答生成メソッドを使用（保存はJobで管理）
    Rails.logger.info "[PROCESS_AI GENERATE] Step 1: Trying NaturalConversationService"
    
    # まずNaturalConversationServiceを試す
    begin
      natural_service = NaturalConversationService.new
      context = { category: conversation.metadata&.dig('category') || 'general' }
      conversation_history = conversation.messages
                                        .order(:created_at)
                                        .limit(10)
                                        .map { |msg| { role: msg.role, content: msg.content } }
      
      Rails.logger.info "[PROCESS_AI GENERATE] Conversation history: #{conversation_history.size} messages"
      
      content = natural_service.generate_natural_response(
        message.content,
        conversation_history,
        context
      )
      
      Rails.logger.info "[PROCESS_AI GENERATE] Natural service response received"
      Rails.logger.info "  - Content length: #{content&.length}"
      Rails.logger.info "  - First 100 chars: #{content&.truncate(100)}"
    rescue StandardError => e
      Rails.logger.error "[PROCESS_AI GENERATE] Natural service failed: #{e.message}"
      Rails.logger.error "  - Error class: #{e.class}"
      content = nil
    end

    # コンテンツが空の場合はフォールバック
    if content.blank?
      Rails.logger.warn "[PROCESS_AI GENERATE] Content is blank, using fallback"
      content = generate_fallback_response(message)
      Rails.logger.info "[PROCESS_AI GENERATE] Fallback content: #{content.truncate(100)}"
    end

    processing_time = (Time.current - start_time).to_f
    Rails.logger.info "[PROCESS_AI GENERATE] Total processing time: #{processing_time}s"

    {
      content: content,
      processing_time: processing_time,
      confidence: 0.8
    }
  rescue StandardError => e
    Rails.logger.error "AI response generation failed: #{e.message}"
    {
      content: generate_fallback_response(message),
      processing_time: (Time.current - start_time).to_f,
      confidence: 0.5
    }
  end

  def generate_fallback_response(message)
    # 質問内容に基づいてフォールバック応答を生成
    content = message.content.downcase
    
    if content.include?('連携') && content.include?('セキュリティ')
      <<~RESPONSE
        ECモール連携とセキュリティについて、順番にお答えいたします。

        【ECモール連携について】
        楽天市場、Amazon、Yahoo!ショッピングの主要3モールとの連携に対応しています。
        商品管理、在庫同期、注文処理を一元化できます。

        【セキュリティ対策について】
        SSL/TLS暗号化、WAF導入、ISO27001準拠の体制でお客様の情報を安全に保護します。

        より詳しい仕様や導入事例について説明が必要でしたら、お聞かせください。
      RESPONSE
    elsif content.include?('連携')
      'ECモール連携についてご案内いたします。主要ECモール（楽天市場、Amazon、Yahoo!ショッピング）との連携に対応しており、商品管理、在庫同期、注文処理を一元化できます。'
    elsif content.include?('セキュリティ')
      'セキュリティ対策についてご案内いたします。SSL/TLS暗号化、WAF導入、ISO27001準拠の体制でお客様の情報を安全に保護します。'
    elsif content.match?(/こんにちは|hello/)
      'こんにちは！お手伝いできることはありますか？'
    elsif content.match?(/ありがとう|thank/)
      'どういたしまして！他にご質問はございますか？'
    else
      "ご質問ありがとうございます。「#{message.content}」について詳しくお聞かせください。"
    end
  end

  def broadcast_error(conversation, error_message)
    ConversationChannel.broadcast_to(
      conversation,
      {
        type: 'error',
        message: 'AI応答の生成中にエラーが発生しました',
        error: error_message
      }
    )
  end
end
