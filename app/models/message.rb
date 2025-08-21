class Message < ApplicationRecord
  # 定数
  ROLES = %w[user assistant system].freeze
  MAX_CONTENT_LENGTH = 10_000

  # アソシエーション
  belongs_to :conversation

  # バリデーション
  validates :content, presence: true,
                      length: { maximum: MAX_CONTENT_LENGTH }
  validates :role, presence: true,
                   inclusion: { in: ROLES }

  # デリゲーション
  delegate :user, to: :conversation

  # スコープ
  scope :by_role, ->(role) { where(role: role) }
  scope :user_messages, -> { by_role('user') }
  scope :assistant_messages, -> { by_role('assistant') }
  scope :recent, -> { order(created_at: :desc) }
  scope :chronological, -> { order(created_at: :asc) }

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
end