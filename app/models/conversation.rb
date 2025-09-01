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

  # 構造化されたメタデータを更新
  def update_structured_metadata(message_content)
    analyzer = InquiryAnalyzerService.new
    analysis = analyzer.analyze(message_content, messages.pluck(:content, :role))
    
    current_metadata = metadata || {}
    
    # 構造化データをマージ
    updated_metadata = current_metadata.deep_merge({
      'category' => analysis[:category],
      'intent' => analysis[:intent],
      'urgency' => analysis[:urgency],
      'keywords' => (current_metadata['keywords'] || []) | analysis[:keywords],
      'entities' => current_metadata.fetch('entities', {}).merge(analysis[:entities]),
      'sentiment_history' => (current_metadata['sentiment_history'] || []) << {
        'timestamp' => Time.current.iso8601,
        'sentiment' => analysis[:sentiment]
      },
      'customer_profile' => analysis[:customer_profile],
      'required_info' => analysis[:required_info],
      'suggested_action' => analysis[:next_action],
      'conversation_stage' => determine_conversation_stage,
      'ai_interaction_count' => (current_metadata['ai_interaction_count'] || 0)
    })
    
    update!(metadata: updated_metadata)
  end

  # 会話のステージを判定
  def determine_conversation_stage
    msg_count = messages.where(role: 'user').count
    
    case msg_count
    when 0..1
      'initial_contact'
    when 2..3
      'information_gathering'
    when 4..5
      'solution_exploration'
    else
      'ready_for_escalation'
    end
  end

  # AIによる自動応答が必要かを判定
  def needs_ai_response?
    return false unless bot_enabled?
    
    stage = determine_conversation_stage
    ai_count = metadata&.dig('ai_interaction_count') || 0
    
    # 3回以上AIが応答していたら人間にエスカレーション
    return false if ai_count >= 3
    
    # 緊急度が高い場合は即エスカレーション
    return false if metadata&.dig('urgency') == 'high'
    
    # それ以外は自動応答
    true
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
