class ProcessAiResponseJob < ApplicationJob
  queue_as :ai_processing

  def perform(message_id)
    message = Message.find(message_id)
    return unless message && message.from_user?

    conversation = message.conversation
    
    # AI応答を生成（仮実装）
    ai_response = generate_ai_response(message)
    
    # AI応答メッセージを作成
    response_message = conversation.messages.create!(
      content: ai_response[:content],
      role: 'assistant',
      metadata: {
        ai_model: 'claude-3',
        processing_time: ai_response[:processing_time],
        confidence: ai_response[:confidence]
      }
    )
    
    # 応答をブロードキャスト
    ActionCable.server.broadcast(
      "conversation_#{conversation.id}",
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
    )
    
    # 会話分析をトリガー
    AnalyzeConversationJob.perform_later(conversation.id)
  rescue StandardError => e
    Rails.logger.error "AI Response Error: #{e.message}"
    broadcast_error(conversation, e.message)
  end

  private

  def generate_ai_response(message)
    start_time = Time.current
    
    # TODO: 実際のAI APIを呼び出す
    # ここでは仮の応答を返す
    content = case message.content.downcase
              when /こんにちは|hello/
                'こんにちは！お手伝いできることはありますか？'
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