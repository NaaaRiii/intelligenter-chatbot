# frozen_string_literal: true

class NeedPreviewJob < ApplicationJob
  queue_as :low_priority

  def perform(conversation_id)
    conversation = Conversation.find(conversation_id)

    messages = conversation.messages
                            .order(:created_at)
                            .last(2)
                            .map { |m| { role: m.role, content: m.content } }

    inference = NeedInferenceService.new.infer(messages: messages)

    analysis = conversation.analyses.find_or_initialize_by(analysis_type: 'needs_preview')
    analysis.analysis_data = inference
    analysis.priority_level = nil
    analysis.sentiment = nil
    analysis.confidence_score = inference['confidence']
    analysis.analyzed_at = Time.current
    analysis.save!

    Rails.logger.info "[NeedPreviewJob] needs_preview saved for conversation ##{conversation_id}"

    # まだUIには出さず裏準備のみ（必要なら以下を有効化）
    # ConversationChannel.broadcast_to(conversation, { type: 'needs_preview', analysis: analysis.as_json })
  rescue ActiveRecord::RecordNotFound
    Rails.logger.warn "[NeedPreviewJob] Conversation not found: #{conversation_id}"
  rescue StandardError => e
    Rails.logger.error "[NeedPreviewJob] Error: #{e.message}"
  end
end


