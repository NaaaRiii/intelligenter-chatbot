# frozen_string_literal: true

# 分析結果をデータベースに保存するサービス
class AnalysisStorageService
  attr_reader :conversation, :analyzer

  def initialize(conversation)
    @conversation = conversation
    @analyzer = SentimentAnalyzer.new
  end

  def store_analysis
    ActiveRecord::Base.transaction do
      sentiment_result = analyze_sentiment
      needs_result = extract_hidden_needs

      analysis = find_or_initialize_analysis

      analysis.assign_attributes(
        analysis_type: 'sentiment',
        analysis_data: build_analysis_data(sentiment_result, needs_result),
        hidden_needs: needs_result[:hidden_needs] || {},
        customer_sentiment: sentiment_result[:overall_sentiment].to_s,
        sentiment: sentiment_result[:overall_sentiment].to_s,
        priority_level: sentiment_result[:escalation_priority].to_s,
        escalated: sentiment_result[:escalation_required],
        escalation_reasons: format_escalation_reasons(sentiment_result[:escalation_reasons]),
        confidence_score: calculate_confidence_score(sentiment_result, needs_result),
        analyzed_at: Time.current
      )

      analysis.save!

      # エスカレーションが必要な場合は処理を実行
      handle_escalation(analysis) if sentiment_result[:escalation_required]

      analysis
    end
  rescue StandardError => e
    Rails.logger.error "Analysis storage failed for conversation ##{conversation.id}: #{e.message}"
    Rails.logger.error e.backtrace.join("\n")
    raise
  end

  private

  def analyze_sentiment
    messages = conversation.messages.map do |message|
      {
        role: message.role,
        content: message.content,
        created_at: message.created_at
      }
    end

    analyzer.analyze_conversation(messages)
  end

  def extract_hidden_needs
    # 隠れたニーズ抽出ロジック（既存のHiddenNeedsExtractorサービスと連携）
    return { hidden_needs: {} } unless defined?(HiddenNeedsExtractor)

    extractor = HiddenNeedsExtractor.new(conversation)
    extractor.extract
  rescue StandardError => e
    Rails.logger.warn "Hidden needs extraction failed: #{e.message}"
    { hidden_needs: {} }
  end

  def find_or_initialize_analysis
    conversation.analyses.find_or_initialize_by(
      analysis_type: 'sentiment'
    )
  end

  def build_analysis_data(sentiment_result, needs_result)
    {
      sentiment: {
        overall: sentiment_result[:overall_sentiment],
        trend: sentiment_result[:sentiment_trend],
        history: sentiment_result[:sentiment_history]
      },
      keywords: sentiment_result[:keyword_insights],
      hidden_needs: needs_result[:hidden_needs],
      timestamp: Time.current.iso8601
    }
  end

  def format_escalation_reasons(reasons)
    return nil if reasons.blank?

    reasons.join("\n")
  end

  def calculate_confidence_score(sentiment_result, needs_result)
    scores = []

    # 感情分析の信頼度
    if sentiment_result[:sentiment_history].present?
      sentiment_scores = sentiment_result[:sentiment_history].filter_map { |h| h.dig(:sentiment, :confidence) }
      scores << (sentiment_scores.sum.to_f / sentiment_scores.size) if sentiment_scores.any?
    end

    # 隠れたニーズ抽出の信頼度
    scores << needs_result[:confidence_score] if needs_result[:confidence_score].present?

    return 0.0 if scores.empty?

    # 平均信頼度を計算
    (scores.sum.to_f / scores.size).round(2)
  end

  def handle_escalation(analysis)
    return unless analysis.escalated?

    # エスカレーション処理（通知など）
    EscalationService.new(analysis).process if defined?(EscalationService)

    # エスカレーションフラグを更新
    analysis.escalate!
  end
end
