class User < ApplicationRecord
  # アソシエーション
  has_many :conversations, dependent: :destroy
  has_many :messages, through: :conversations

  # バリデーション
  validates :email, presence: true,
                    uniqueness: { case_sensitive: false },
                    format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :name, presence: true

  # コールバック
  before_create :generate_api_token

  # スコープ
  scope :active_recently, -> { where('last_active_at > ?', 1.week.ago) }
  scope :active, -> { where('last_active_at > ?', 24.hours.ago) }
  scope :with_conversations, -> { joins(:conversations).distinct }

  # メソッド
  def update_last_active!
    update!(last_active_at: Time.current)
  end

  def active_conversation
    conversations.active.last
  end

  def recent_conversations(limit = 10)
    conversations.includes(:messages)
                 .order(created_at: :desc)
                 .limit(limit)
  end

  def display_name
    name.presence || email.split('@').first
  end

  def conversation_count
    conversations.count
  end

  def average_sentiment_score
    analyses = Analysis.joins(:conversation).where(conversations: { user_id: id })
    scores = analyses.filter_map(&:sentiment_score)
    return nil if scores.empty?

    scores.sum.to_f / scores.size
  end

  def admin?
    # TODO: 実際の管理者判定ロジックを実装
    email&.ends_with?('@admin.com') || false
  end

  def regenerate_api_token!
    generate_api_token
    save!
  end

  private

  def generate_api_token
    self.api_token = SecureRandom.hex(32)
  end
end
