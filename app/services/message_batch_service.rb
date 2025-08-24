# frozen_string_literal: true

# メッセージのバッチ保存を処理するサービス
class MessageBatchService
  include ActiveModel::Model

  attr_accessor :conversation, :messages_data, :skip_callbacks

  validates :conversation, presence: true
  validates :messages_data, presence: true

  # バッチサイズの制限
  MAX_BATCH_SIZE = 100

  def initialize(conversation:, messages_data: [], skip_callbacks: false)
    @conversation = conversation
    @messages_data = messages_data
    @skip_callbacks = skip_callbacks
  end

  # メッセージをバッチで保存
  def save_batch
    return false unless valid?
    return false if messages_data.size > MAX_BATCH_SIZE
    return false unless validate_messages_data

    ActiveRecord::Base.transaction do
      if skip_callbacks
        bulk_insert_messages
      else
        create_messages_with_callbacks
      end
    end

    true
  rescue ActiveRecord::RecordInvalid => e
    errors.add(:base, "メッセージの保存に失敗しました: #{e.message}")
    false
  rescue StandardError => e
    Rails.logger.error "Batch save failed: #{e.message}"
    errors.add(:base, 'システムエラーが発生しました')
    false
  end

  # 非同期でバッチ保存（Sidekiqジョブ経由）
  def save_batch_async
    return false unless valid?

    MessageBatchJob.perform_later(
      conversation_id: conversation.id,
      messages_data: messages_data
    )
    true
  end

  # ストリーミング保存（大量データ用）
  def self.stream_save(conversation:, message_stream:, batch_size: 50)
    buffer = []
    saved_count = 0

    message_stream.each do |message_data|
      buffer << message_data

      next unless buffer.size >= batch_size

      service = new(
        conversation: conversation,
        messages_data: buffer,
        skip_callbacks: true
      )

      raise "Failed to save batch: #{service.errors.full_messages.join(', ')}" unless service.save_batch

      saved_count += buffer.size
      buffer.clear
    end

    # 残りのメッセージを保存
    unless buffer.empty?
      service = new(
        conversation: conversation,
        messages_data: buffer,
        skip_callbacks: true
      )

      saved_count += buffer.size if service.save_batch
    end

    saved_count
  end

  private

  def validate_messages_data
    messages_data.each_with_index do |data, index|
      content = data[:content].to_s
      role = data[:role] || 'user'

      if content.blank?
        errors.add(:base, "無効なメッセージデータ (index=#{index}): contentが空です")
        return false
      end

      unless Message::ROLES.include?(role)
        errors.add(:base, "無効なメッセージデータ (index=#{index}): 不正なrole=#{role}")
        return false
      end
    end

    true
  end

  # バルクインサート（コールバックをスキップ）
  def bulk_insert_messages
    now = Time.current
    insert_data = messages_data.map do |data|
      {
        conversation_id: conversation.id,
        content: data[:content],
        role: data[:role] || 'user',
        metadata: data[:metadata]&.to_json || '{}',
        created_at: data[:created_at] || now,
        updated_at: now
      }
    end

    Message.insert_all!(insert_data)

    # 会話のタイムスタンプを更新
    conversation.touch

    # キャッシュをクリア
    Message.expire_conversation_cache(conversation.id)
  end

  # コールバック付きでメッセージを作成
  def create_messages_with_callbacks
    messages = []

    messages_data.each do |data|
      message = conversation.messages.build(
        content: data[:content],
        role: data[:role] || 'user',
        metadata: data[:metadata] || {}
      )

      message.created_at = data[:created_at] if data[:created_at].present?

      message.save!
      messages << message
    end

    messages
  end
end
