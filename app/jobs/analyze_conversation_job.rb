# frozen_string_literal: true

# 会話をClaude APIで分析し、結果を保存するジョブ
class AnalyzeConversationJob < ApplicationJob
  queue_as :default

  # エスカレーション閾値
  HIGH_PRIORITY_THRESHOLD = 'high'
  FRUSTRATED_SENTIMENT = 'frustrated'

  # rubocop:disable Metrics/AbcSize
  def perform(conversation_id)
    conversation = Conversation.find(conversation_id)

    # 会話履歴を構築
    conversation_history = build_conversation_history(conversation)
    return if conversation_history.empty?

    # Claude APIで分析
    service = ClaudeApiService.new
    analysis_result = service.analyze_conversation(
      conversation_history,
      conversation.messages.last&.content
    )

    # 分析結果を保存
    analysis = save_analysis(conversation, analysis_result)

    # エスカレーション判定
    handle_escalation(conversation, analysis) if requires_escalation?(analysis_result)

    # リアルタイムで分析結果を配信
    broadcast_analysis_result(conversation, analysis_result)

    Rails.logger.info "Analysis completed for conversation ##{conversation_id}"
  rescue StandardError => e
    Rails.logger.error "Analysis failed for conversation ##{conversation_id}: #{e.message}"
    Rails.logger.error e.backtrace.join("\n")

    # エラー時もフォールバック分析を保存
    save_fallback_analysis(conversation, e.message)
  end

  private

  def build_conversation_history(conversation)
    conversation.messages.order(:created_at).map do |message|
      {
        role: message.role,
        content: message.content,
        created_at: message.created_at
      }
    end
  end

  def save_analysis(conversation, analysis_result)
    analysis = conversation.analyses.find_or_initialize_by(
      analysis_type: 'needs'
    )

    analysis.update!(
      analysis_data: analysis_result,
      hidden_needs: analysis_result['hidden_needs'],
      sentiment: analysis_result['customer_sentiment'],
      priority_level: analysis_result['priority_level'],
      escalated: analysis_result['escalation_required'] || false,
      escalation_reason: analysis_result['escalation_reason'],
      analyzed_at: Time.current,
      confidence_score: calculate_average_confidence(analysis_result)
    )

    analysis
  end

  def save_fallback_analysis(conversation, error_message)
    conversation.analyses.create!(
      analysis_type: 'needs',
      analysis_data: {
        'error' => error_message,
        'fallback' => true
      },
      sentiment: 'neutral',
      priority_level: 'low',
      analyzed_at: Time.current
    )
  end

  def calculate_average_confidence(analysis_result)
    needs = analysis_result['hidden_needs'] || []
    return 0.0 if needs.empty?

    total_confidence = needs.sum { |need| need['confidence'].to_f }
    total_confidence / needs.size
  end

  def requires_escalation?(analysis_result)
    analysis_result['escalation_required'] ||
      analysis_result['priority_level'] == HIGH_PRIORITY_THRESHOLD ||
      analysis_result['customer_sentiment'] == FRUSTRATED_SENTIMENT
  end

  def handle_escalation(conversation, analysis)
    # Slackへの通知
    notify_slack(conversation, analysis) if slack_configured?

    # メール通知
    if email_configured?
      EscalationMailer.alert(
        conversation_id: conversation.id,
        summary: build_escalation_summary(analysis)
      ).deliver_later
    end

    # エスカレーション記録
    analysis.escalate!

    Rails.logger.info "Escalation triggered for conversation ##{conversation.id}"
  end
  # rubocop:enable Metrics/AbcSize

  def notify_slack(conversation, analysis)
    text = build_slack_message(conversation, analysis)

    EscalationNotifier.to_slack(
      text,
      channel: '#support-escalations'
    )
  rescue StandardError => e
    Rails.logger.error "Slack notification failed: #{e.message}"
    Rails.logger.error "Backtrace: #{e.backtrace.first(5).join("\n")}" if e.backtrace
  end

  def build_slack_message(conversation, analysis)
    hidden_needs = analysis.hidden_needs || []
    needs = hidden_needs.first(3).map do |n|
      next unless n.is_a?(Hash)

      "• #{n['need_type']}: #{n['evidence']}"
    end.compact.join("\n")

    <<~MESSAGE
      🚨 *エスカレーションが必要な会話を検出*

      *会話ID:* ##{conversation.id}
      *ユーザー:* #{conversation.user&.email || 'Unknown'}
      *優先度:* #{analysis.priority_level}
      *感情:* #{analysis.sentiment}
      *理由:* #{analysis.escalation_reason}

      *検出されたニーズ:*
      #{needs}

      <#{conversation_url(conversation)}|会話を確認>
    MESSAGE
  end

  def build_escalation_summary(analysis)
    hidden_needs = analysis.hidden_needs || []
    needs = hidden_needs.first(3).map do |n|
      next unless n.is_a?(Hash)

      n['proactive_suggestion']
    end.compact.join(', ')

    "優先度: #{analysis.priority_level}, 感情: #{analysis.sentiment}, 推奨アクション: #{needs}"
  end

  def broadcast_analysis_result(conversation, analysis_result)
    ActionCable.server.broadcast(
      "conversation_#{conversation.id}",
      {
        type: 'analysis_complete',
        analysis: {
          hidden_needs: analysis_result['hidden_needs'],
          sentiment: analysis_result['customer_sentiment'],
          priority: analysis_result['priority_level'],
          suggestions: extract_suggestions(analysis_result)
        }
      }
    )
  end

  # rubocop:disable Rails/Pluck
  def extract_suggestions(analysis_result)
    (analysis_result['hidden_needs'] || []).map do |need|
      need['proactive_suggestion']
    end.compact
  end
  # rubocop:enable Rails/Pluck

  def conversation_url(conversation)
    default_url_options = Rails.application.config.action_mailer.default_url_options || {}
    host = default_url_options[:host] || 'localhost:3000'

    "http://#{host}/conversations/#{conversation.id}"
  end

  def slack_configured?
    ENV['SLACK_WEBHOOK_URL'].present? ||
      Rails.application.credentials.dig(:slack, :webhook_url).present?
  end

  def email_configured?
    ActionMailer::Base.smtp_settings.present?
  end
end
