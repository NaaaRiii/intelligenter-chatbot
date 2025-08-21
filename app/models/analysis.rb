class Analysis < ApplicationRecord
  # 定数
  ANALYSIS_TYPES = %w[needs sentiment escalation pattern].freeze
  PRIORITY_LEVELS = %w[low medium high urgent].freeze
  SENTIMENTS = %w[positive neutral negative frustrated].freeze

  # アソシエーション
  belongs_to :conversation

  # バリデーション
  validates :analysis_type, presence: true,
                            inclusion: { in: ANALYSIS_TYPES }
  validates :analysis_data, presence: true
  validates :priority_level, inclusion: { in: PRIORITY_LEVELS },
                             allow_nil: true
  validates :sentiment, inclusion: { in: SENTIMENTS },
                       allow_nil: true

  # デリゲーション
  delegate :user, to: :conversation

  # スコープ
  scope :by_type, ->(type) { where(analysis_type: type) }
  scope :escalated, -> { where(escalated: true) }
  scope :not_escalated, -> { where(escalated: false) }
  scope :high_priority, -> { where(priority_level: %w[high urgent]) }
  scope :recent, -> { order(created_at: :desc) }
  scope :needs_escalation, -> { where(priority_level: 'high', escalated: false) }

  # メソッド
  def needs_escalation?
    priority_level == 'urgent' || sentiment == 'frustrated'
  end

  def escalate!
    return if escalated?
    
    update!(
      escalated: true,
      escalated_at: Time.current
    )
  end

  def hidden_needs
    return [] unless analysis_data && analysis_data['hidden_needs']
    analysis_data['hidden_needs']
  end
  
  def extract_hidden_needs
    hidden_needs
  end

  def sentiment_score
    analysis_data&.dig('sentiment', 'score')
  end
  
  def confidence_score
    analysis_data&.dig('confidence_score') || 0.0
  end

  def evidence_quotes
    analysis_data&.dig('evidence_quotes') || []
  end
  
  def requires_escalation?
    return false if escalated?
    priority_level == 'high' || sentiment == 'frustrated'
  end

  def update_analysis_data(key, value)
    self.analysis_data ||= {}
    self.analysis_data[key] = value
    save!
  end
end