# frozen_string_literal: true

# メッセージのバッチ保存を非同期で処理するジョブ
class MessageBatchJob < ApplicationJob
  queue_as :default

  def perform(conversation_id:, messages_data:)
    conversation = Conversation.find(conversation_id)

    service = MessageBatchService.new(
      conversation: conversation,
      messages_data: messages_data,
      skip_callbacks: true
    )

    return after_batch_save(conversation) if service.save_batch

    error_msg = "Failed to save batch for conversation #{conversation_id}"
    Rails.logger.error "#{error_msg}: #{service.errors.full_messages}"
    raise StandardError, service.errors.full_messages.join(', ')
  rescue ActiveRecord::RecordNotFound => e
    Rails.logger.error "Conversation not found: #{e.message}"
  end

  private

  def after_batch_save(conversation)
    # 会話分析をトリガー
    AnalyzeConversationJob.perform_later(conversation.id) if should_analyze?(conversation)

    # WebSocketで通知
    notify_batch_complete(conversation)
  end

  def should_analyze?(conversation)
    # 最後の分析から1時間以上経過している場合
    last_analysis = conversation.analyses.last
    return true if last_analysis.nil?

    last_analysis.created_at < 1.hour.ago
  end

  def notify_batch_complete(conversation)
    ActionCable.server.broadcast(
      "conversation_#{conversation.id}",
      {
        type: 'batch_messages_saved',
        conversation_id: conversation.id,
        message_count: conversation.messages.count,
        timestamp: Time.current
      }
    )
  end
end
