class ProcessAiResponseJob < ApplicationJob
  queue_as :ai_processing

  def perform(message_id)
    message = Message.find(message_id)
    return unless message&.from_user?

    process_ai_response(message)
  rescue StandardError => e
    Rails.logger.error "AI Response Error: #{e.message}"
    broadcast_error(message.conversation, e.message) if message
  end

  private

  def process_ai_response(message)
    conversation = message.conversation
    ai_response = generate_ai_response(message)
    response_message = create_ai_message(conversation, ai_response)
    broadcast_ai_message(conversation, response_message)
    AnalyzeConversationJob.perform_later(conversation.id)
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
    ActionCable.server.broadcast(
      "conversation_#{conversation.id}",
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

    # TODO: 実際のAI APIを呼び出す
    # ここでは仮の応答を返す
    content = case message.content.downcase
              when /こんにちは|hello/
                'こんにちは！お手伝いできることはありますか？'
              when /使い方|教えて|どうやって|なぜ|どうして|いつ|どこ|何|\?|？|質問/
                'ご質問ありがとうございます。お問い合わせ内容を確認いたします。'
              when /困って|エラー|不具合|苦情/
                '申し訳ございません。ご不便をおかけしております。状況をお知らせください。'
              when /ありがとう|thank/
                'どういたしまして！他にご質問はございますか？'
              when /さようなら|bye/
                'ご利用ありがとうございました。またお待ちしております。'
              else
                "「#{message.content}」について承知いたしました。詳しくお聞かせください。"
              end

    {
      content: content,
      processing_time: (Time.current - start_time).to_f,
      confidence: 0.95
    }
  end

  def broadcast_error(conversation, error_message)
    ActionCable.server.broadcast(
      "conversation_#{conversation.id}",
      {
        type: 'error',
        message: 'AI応答の生成中にエラーが発生しました',
        error: error_message
      }
    )
  end
end
