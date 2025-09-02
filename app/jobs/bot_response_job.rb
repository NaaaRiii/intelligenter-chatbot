# frozen_string_literal: true

# ボット応答を非同期で処理するジョブ
class BotResponseJob < ApplicationJob
  queue_as :high_priority

  # リトライ設定
  retry_on StandardError, wait: 5.seconds, attempts: 3

  def perform(conversation_id:, user_message_id:)
    Rails.logger.info "="*80
    Rails.logger.info "[JOB FLOW START] BotResponseJob#perform"
    Rails.logger.info "Conversation ID: #{conversation_id}"
    Rails.logger.info "User Message ID: #{user_message_id}"
    Rails.logger.info "="*80
    
    conversation, user_message = load_records(conversation_id, user_message_id)
    
    Rails.logger.info "[JOB STEP 1] Records loaded"
    Rails.logger.info "  - User Message: #{user_message.content}"
    Rails.logger.info "  - Message Role: #{user_message.role}"
    
    unless valid_user_message?(user_message, conversation_id)
      Rails.logger.warn "[JOB WARNING] Invalid user message, skipping"
      return
    end

    Rails.logger.info "[JOB STEP 2] Generating bot response via ChatBotService"
    bot_response = generate_bot_response(conversation, user_message)
    
    if bot_response
      Rails.logger.info "[JOB STEP 3] Bot response generated successfully"
      Rails.logger.info "  - Response ID: #{bot_response.id}"
      Rails.logger.info "  - Response Content: #{bot_response.content&.truncate(200)}"
    else
      Rails.logger.error "[JOB ERROR] Bot response generation failed"
    end
    
    handle_response(conversation, user_message, bot_response)
    
    Rails.logger.info "[JOB FLOW END] BotResponseJob#perform"
    Rails.logger.info "="*80
  rescue ActiveRecord::RecordNotFound => e
    Rails.logger.error "[JOB ERROR] Record not found: #{e.message}"
  end

  private

  def load_records(conversation_id, user_message_id)
    [Conversation.find(conversation_id), Message.find(user_message_id)]
  end

  def valid_user_message?(user_message, conversation_id)
    user_message.role == 'user' && user_message.conversation_id == conversation_id
  end

  def generate_bot_response(conversation, user_message)
    Rails.logger.info "[JOB] Calling ChatBotService.generate_response"
    ChatBotService.new(
      conversation: conversation,
      user_message: user_message
    ).generate_response
  end

  def handle_response(conversation, user_message, bot_response)
    if bot_response.nil?
      Rails.logger.error "Failed to generate bot response for message #{user_message.id}"
      handle_error(conversation, user_message)
    else
      broadcast_bot_message(conversation, bot_response)
      after_response_generated(conversation, bot_response)
    end
  end

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
    # ConversationChannelの形式に合わせる
    ConversationChannel.broadcast_to(
      conversation,
      {
        message: error_message.as_json(
          only: [:id, :content, :role, :created_at, :metadata]
        )
      }
    )
  end

  def broadcast_bot_message(conversation, message)
    # ConversationChannelの形式に合わせる
    ConversationChannel.broadcast_to(
      conversation,
      {
        message: message.as_json(
          only: [:id, :content, :role, :created_at, :metadata]
        )
      }
    )
  end
end
