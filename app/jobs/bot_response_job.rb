# frozen_string_literal: true

# ボット応答を非同期で処理するジョブ
class BotResponseJob < ApplicationJob
  queue_as :high_priority

  # リトライ設定
  retry_on StandardError, wait: 5.seconds, attempts: 3

  def perform(conversation_id:, user_message_id:)
    conversation = Conversation.find(conversation_id)
    user_message = Message.find(user_message_id)

    # ユーザーメッセージであることを確認
    return unless user_message.role == 'user'
    return unless user_message.conversation_id == conversation_id

    # ボット応答を生成
    bot_service = ChatBotService.new(
      conversation: conversation,
      user_message: user_message
    )

    bot_response = bot_service.generate_response

    if bot_response.nil?
      Rails.logger.error "Failed to generate bot response for message #{user_message_id}"
      handle_error(conversation, user_message)
    else
      broadcast_bot_message(conversation, bot_response)
      after_response_generated(conversation, bot_response)
    end
  rescue ActiveRecord::RecordNotFound => e
    Rails.logger.error "Record not found: #{e.message}"
  end

  private

  # エラー時の処理
  def handle_error(conversation, user_message)
    error_message = nil

    conversation.with_lock do
      relation = conversation.messages
                             .where(role: 'assistant')
                             .where('metadata @> ?', { error: true, original_message_id: user_message.id }.to_json)

      error_message = relation.first

      error_message ||= conversation.messages.create!(
        content: '申し訳ございません。現在システムに問題が発生しています。しばらくしてから再度お試しください。',
        role: 'assistant',
        metadata: {
          error: true,
          original_message_id: user_message.id
        }
      )
    end

    # WebSocketで通知
    broadcast_error(conversation, error_message)
  end

  # 応答生成後の処理
  def after_response_generated(conversation, bot_response)
    AnalyzeConversationJob.perform_later(conversation.id) if should_analyze_conversation?(conversation)
    record_metrics(conversation, bot_response)
  end

  def should_analyze_conversation?(conversation)
    (conversation.messages.count % 10).zero?
  end

  def record_metrics(conversation, bot_response)
    Rails.logger.info(
      {
        event: 'bot_response_generated',
        conversation_id: conversation.id,
        response_id: bot_response.id,
        intent: bot_response.metadata['intent'],
        confidence: bot_response.metadata['confidence']
      }.to_json
    )
  end

  def broadcast_error(conversation, error_message)
    ActionCable.server.broadcast(
      "conversation_#{conversation.id}",
      {
        type: 'bot_error',
        message: {
          id: error_message.id,
          content: error_message.content,
          role: error_message.role,
          created_at: error_message.created_at
        }
      }
    )
  end

  def broadcast_bot_message(conversation, message)
    ActionCable.server.broadcast(
      "conversation_#{conversation.id}",
      {
        type: 'new_message',
        message: {
          id: message.id,
          content: message.content,
          role: message.role,
          created_at: message.created_at
        }
      }
    )
  end
end
