class Conversation < ApplicationRecord
  # アソシエーション
  belongs_to :user, optional: true  # ユーザーはオプショナル（ゲストセッション対応）
  has_many :messages, dependent: :destroy
  has_many :analyses, dependent: :destroy

  # バリデーション
  validates :session_id, presence: true, uniqueness: true

  # コールバック
  before_validation :generate_session_id, on: :create

  # スコープ
  scope :active, -> { where(ended_at: nil) }
  scope :ended, -> { where.not(ended_at: nil) }
  scope :recent, -> { order(created_at: :desc) }
  scope :with_messages, -> { includes(:messages) }

  # メソッド
  def active?
    ended_at.nil?
  end

  def end_conversation!
    update!(ended_at: Time.current) if active?
  end

  def duration
    if ended_at
      ended_at - created_at
    elsif persisted?
      Time.current - created_at
    end
  end

  def message_count
    messages.count
  end

  def latest_analysis
    analyses.order(created_at: :desc).first
  end

  def add_message(content:, role:, metadata: {})
    messages.create!(
      content: content,
      role: role,
      metadata: metadata
    )
  end

  # ボット機能が有効かチェック
  def bot_enabled?
    # metadataまたは設定に基づいて判定
    metadata&.dig('bot_enabled') != false
  end

  # 最後のユーザーメッセージを取得
  def last_user_message
    messages.user_messages.latest_n(1).first
  end

  private

  def generate_session_id
    self.session_id ||= SecureRandom.uuid
  end
end
