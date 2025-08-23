class Message < ApplicationRecord
  include CacheableMessage

  # 定数
  ROLES = %w[user assistant system].freeze
  MAX_CONTENT_LENGTH = 2_000

  # アソシエーション
  belongs_to :conversation

  # バリデーション
  validates :content, presence: true,
                      length: { maximum: MAX_CONTENT_LENGTH }
  validates :role, presence: true,
                   inclusion: { in: ROLES }

  # コールバック
  after_create :update_conversation_timestamp
  after_create :broadcast_message

  # デリゲーション
  delegate :user, to: :conversation

  # スコープ
  scope :by_role, ->(role) { where(role: role) }
  scope :user_messages, -> { by_role('user') }
  scope :assistant_messages, -> { by_role('assistant') }
  scope :recent, -> { order(created_at: :desc) }
  scope :chronological, -> { order(created_at: :asc) }

  # パフォーマンス最適化スコープ
  scope :with_conversation, -> { includes(:conversation) }
  scope :for_conversation, ->(conversation_id) { where(conversation_id: conversation_id) }
  scope :created_after, ->(date) { where('created_at > ?', date) }
  scope :created_before, ->(date) { where(created_at: ...date) }
  scope :created_between, ->(start_date, end_date) { where(created_at: start_date..end_date) }
  scope :latest_n, ->(n) { order(created_at: :desc, id: :desc).limit(n) }
  scope :paginated, ->(page, per_page = 50) { offset((page - 1) * per_page).limit(per_page) }

  # メタデータ検索用スコープ（PostgreSQL JSONB）
  scope :with_metadata_key, ->(key) { where('metadata ? :key', key: key) }
  scope :with_metadata_value, ->(key, value) { where('metadata @> ?', { key => value }.to_json) }

  # バッチ取得用スコープ
  scope :in_batches_of, ->(size) { find_in_batches(batch_size: size) }

  # メソッド
  def user?
    role == 'user'
  end

  def from_user?
    user?
  end

  def assistant?
    role == 'assistant'
  end

  def from_assistant?
    assistant?
  end

  def from_system?
    role == 'system'
  end

  def formatted_timestamp
    created_at.strftime('%Y年%m月%d日 %H:%M')
  end

  def word_count
    content.split.size
  end

  def add_metadata(key, value)
    self.metadata ||= {}
    self.metadata[key] = value
    save!
  end

  private

  def update_conversation_timestamp
    # touchと同じ動作だが、Rubocopの警告を回避
    conversation.update!(updated_at: Time.current)
  end

  def broadcast_message
    ActionCable.server.broadcast(
      "conversation_#{conversation_id}",
      { message: as_json }
    )
  end
end
