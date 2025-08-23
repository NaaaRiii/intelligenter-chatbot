# frozen_string_literal: true

require 'net/http'
require 'uri'
require 'json'

# エスカレーション通知を管理するサービス
class EscalationNotifier
  class NotificationError < StandardError; end

  # Slack通知を送信
  def self.to_slack(text, channel: '#support')
    webhook_url = ENV.fetch('SLACK_WEBHOOK_URL') { Rails.application.credentials.dig(:slack, :webhook_url) }

    return false if webhook_url.blank?

    payload = {
      text: text,
      channel: channel,
      username: 'CS Analysis Bot',
      icon_emoji: ':robot_face:'
    }

    post_json?(webhook_url, payload)
  rescue StandardError => e
    Rails.logger.error "Slack notification error: #{e.message}"
    false
  end

  # メール通知のヘルパー（EscalationMailerと連携）
  def self.to_email(conversation_id, summary)
    EscalationMailer.alert(
      conversation_id: conversation_id,
      summary: summary
    ).deliver_later

    true
  rescue StandardError => e
    Rails.logger.error "Email notification error: #{e.message}"
    false
  end

  # Teams通知（将来的な拡張用）
  def self.to_teams(text, webhook_url: nil)
    webhook_url ||= ENV.fetch('TEAMS_WEBHOOK_URL', nil)
    return false if webhook_url.blank?

    payload = {
      '@type': 'MessageCard',
      '@context': 'https://schema.org/extensions',
      summary: 'エスカレーション通知',
      themeColor: 'FF0000',
      sections: [{
        activityTitle: 'カスタマーサポート エスカレーション',
        text: text,
        markdown: true
      }]
    }

    post_json?(webhook_url, payload)
  rescue StandardError => e
    Rails.logger.error "Teams notification error: #{e.message}"
    false
  end

  # 複数チャネルへの一括通知
  def self.broadcast(conversation, analysis, channels: [:slack])
    results = {}

    channels.each do |channel|
      results[channel] = case channel
                         when :slack
                           to_slack(
                             build_notification_text(conversation, analysis),
                             channel: '#support-escalations'
                           )
                         when :email
                           to_email(
                             conversation.id,
                             build_summary(analysis)
                           )
                         when :teams
                           to_teams(build_notification_text(conversation, analysis))
                         else
                           false
                         end
    end

    results
  end

  def self.build_notification_text(conversation, analysis)
    <<~TEXT
      ⚠️ **エスカレーションが必要な会話**

      **会話ID:** ##{conversation.id}
      **優先度:** #{analysis.priority_level}
      **感情分析:** #{analysis.sentiment}
      **信頼度:** #{(analysis.confidence_score * 100).round(1)}%

      **検出された隠れたニーズ:**
      #{format_needs(analysis.hidden_needs)}

      **推奨アクション:**
      #{format_suggestions(analysis.hidden_needs)}

      **理由:** #{analysis.escalation_reason}

      [会話を確認](#{conversation_url(conversation)})
    TEXT
  end

  def self.build_summary(analysis)
    needs = analysis.hidden_needs.first(3).pluck('need_type').join(', ')
    "優先度: #{analysis.priority_level}, ニーズ: #{needs}"
  end

  def self.format_needs(needs)
    return 'なし' if needs.blank?

    needs.first(5).map do |need|
      "• **#{need['need_type']}**: #{need['evidence']} (信頼度: #{(need['confidence'] * 100).round}%)"
    end.join("\n")
  end

  def self.format_suggestions(needs)
    return 'なし' if needs.blank?

    needs.first(3).map do |need|
      "• #{need['proactive_suggestion']}"
    end.join("\n")
  end

  def self.conversation_url(conversation)
    Rails.application.routes.url_helpers.conversation_url(
      conversation,
      host: Rails.application.config.action_mailer.default_url_options[:host] || 'localhost:3000'
    )
  end

  private_class_method :build_notification_text, :build_summary, :format_needs,
                       :format_suggestions, :conversation_url

  def self.post_json?(webhook_url, payload)
    uri = URI.parse(webhook_url)
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = (uri.scheme == 'https')

    request = Net::HTTP::Post.new(uri.request_uri)
    request['Content-Type'] = 'application/json'
    request.body = payload.to_json

    response = http.request(request)
    raise NotificationError, "Notification failed: #{response.body}" unless response.code == '200'

    true
  end
  private_class_method :post_json?
end
