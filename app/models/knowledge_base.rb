# frozen_string_literal: true

class KnowledgeBase < ApplicationRecord
  # Associations
  belongs_to :conversation, optional: true
  
  # Constants
  PATTERN_TYPES = %w[successful_conversation failed_conversation best_practice template faq product_info resolution_pattern].freeze
  HIGH_SCORE_THRESHOLD = 80
  SUCCESS_THRESHOLD = 70
  
  # Validations
  validates :pattern_type, presence: true, inclusion: { in: PATTERN_TYPES }
  validates :content, presence: true
  validates :success_score, numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: 100 }
  
  # Scopes
  scope :high_score, -> { where('success_score >= ?', HIGH_SCORE_THRESHOLD) }
  scope :by_type, ->(type) { where(pattern_type: type) }
  scope :ordered_by_score, -> { order(success_score: :desc) }
  scope :with_tags, ->(tags) { where('tags && ARRAY[?]::varchar[]', tags) }
  scope :search, ->(keyword) { where('summary ILIKE ?', "%#{keyword}%") }
  
  # Callbacks
  before_save :generate_summary_if_needed
  before_save :set_default_metadata
  
  # Instance methods
  def successful?
    success_score >= SUCCESS_THRESHOLD
  end
  
  def add_tags(new_tags)
    self.tags = (tags + new_tags).uniq
  end
  
  def extract_key_phrases
    return [] unless content['messages']
    
    phrases = []
    content['messages'].each do |message|
      text = message['content'] || message[:content]
      next unless text
      
      # 簡易的なキーフレーズ抽出
      # プラン名を抽出
      phrases.concat(text.scan(/(?:ベーシック|スタンダード|エンタープライズ|プレミアム)プラン/))
      # 機能名を抽出
      phrases.concat(text.scan(/(?:料金|機能|サポート|導入|契約|分析|データ)(?:プラン|機能|サービス)?/))
    end
    
    phrases.uniq
  end
  
  def similarity_to(other)
    return 0 if tags.empty? || other.tags.empty?
    
    intersection = tags & other.tags
    union = tags | other.tags
    
    intersection.size.to_f / union.size
  end
  
  private
  
  def generate_summary_if_needed
    return if summary.present?
    
    return unless content['messages']
    
    # メッセージから要約を生成
    messages = content['messages']
    key_points = []
    
    messages.each do |msg|
      text = msg['content'] || msg[:content]
      next unless text
      
      # 重要なキーワードを含む場合は要約に追加
      if text =~ /導入|検討|契約|購入/
        key_points << '導入検討'
      end
      if text =~ /料金|価格|費用|プラン/
        key_points << '料金確認'
      end
      if text =~ /機能|できる|サポート/
        key_points << '機能確認'
      end
      if text =~ /ありがとう|助かりました|解決/
        key_points << '問題解決'
      end
    end
    
    self.summary = key_points.uniq.join('、') if key_points.any?
    self.summary ||= '会話記録'
  end
  
  def set_default_metadata
    self.metadata ||= {}
    self.metadata['created_at'] ||= Time.current.to_s
    self.metadata['version'] ||= '1.0'
  end
end