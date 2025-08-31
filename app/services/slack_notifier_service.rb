# frozen_string_literal: true

require 'net/http'
require 'json'
require 'uri'

class SlackNotifierService
  # カテゴリとSlackチャンネルのマッピング
  # サービス概要・能力範囲 → カスタマーサービス
  # 技術・システム関連 → エンジニアリング
  # プロジェクト進行・体制、費用・契約、実績・事例 → セールス
  # 初回相談・問い合わせ → カスタマーサービス
  # マーケティング戦略 → マーケティング
  
  def self.channel_webhooks
    {
      marketing: ENV['SLACK_MARKETING_WEBHOOK_URL'] || 'https://hooks.slack.com/services/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',
      customer_service: ENV['SLACK_CUSTOMER_SERVICE_WEBHOOK_URL'] || 'https://hooks.slack.com/services/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',
      engineering: ENV['SLACK_ENGINEERING_WEBHOOK_URL'] || 'https://hooks.slack.com/services/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',
      sales: ENV['SLACK_SALES_WEBHOOK_URL'] || 'https://hooks.slack.com/services/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'
    }
  end

  def self.notify_new_inquiry(category:, customer_name:, message:, conversation_id:)
    new.notify_new_inquiry(
      category: category, 
      customer_name: customer_name, 
      message: message,
      conversation_id: conversation_id
    )
  end

  def notify_new_inquiry(category:, customer_name:, message:, conversation_id:)
    webhook_url = webhook_url_for(category)
    Rails.logger.info "Slack notification - category: #{category}, webhook_url present: #{webhook_url.present?}"
    
    return unless webhook_url

    payload = build_inquiry_payload(
      category: category,
      customer_name: customer_name,
      message: message,
      conversation_id: conversation_id
    )

    Rails.logger.info "Sending Slack notification to webhook for conversation #{conversation_id}"
    send_to_slack(webhook_url, payload)
  rescue => e
    Rails.logger.error "Slack notification failed: #{e.message}"
    Rails.logger.error e.backtrace.join("\n")
    false
  end

  private

  def webhook_url_for(category)
    case category.to_s.downcase
    when 'marketing'
      self.class.channel_webhooks[:marketing]
    when 'service'  # サービス概要・能力範囲
      self.class.channel_webhooks[:customer_service]
    when 'tech'  # 技術・システム関連
      self.class.channel_webhooks[:engineering]
    when 'project'  # プロジェクト進行・体制
      self.class.channel_webhooks[:sales]
    when 'cost', 'pricing'  # 費用・契約
      self.class.channel_webhooks[:sales]
    when 'case', 'cases'  # 実績・事例
      self.class.channel_webhooks[:sales]
    when 'consultation'  # 初回相談・問い合わせ
      self.class.channel_webhooks[:customer_service]
    else
      nil
    end
  end

  def build_inquiry_payload(category:, customer_name:, message:, conversation_id:)
    {
      text: "🔔 新規お問い合わせ（#{category_display_name(category)}）",
      blocks: [
        {
          type: "header",
          text: {
            type: "plain_text",
            text: "📬 新規お問い合わせがありました",
            emoji: true
          }
        },
        {
          type: "section",
          fields: [
            {
              type: "mrkdwn",
              text: "*カテゴリー:*\n#{category_display_name(category)}"
            },
            {
              type: "mrkdwn", 
              text: "*お客様名:*\n#{customer_name}"
            }
          ]
        },
        {
          type: "section",
          text: {
            type: "mrkdwn",
            text: "*お問い合わせ内容:*\n```#{message}```"
          }
        },
        {
          type: "section",
          text: {
            type: "mrkdwn",
            text: "*対応ページ:*\n<#{Rails.application.config.app_url}/dashboard|ダッシュボードで確認>"
          }
        },
        {
          type: "context",
          elements: [
            {
              type: "mrkdwn",
              text: "会話ID: #{conversation_id} | 受信時刻: #{Time.current.strftime('%Y-%m-%d %H:%M:%S')}"
            }
          ]
        }
      ]
    }
  end

  def category_display_name(category)
    case category.to_s.downcase
    when 'marketing'
      '📈 マーケティング戦略'
    when 'service'
      '🏢 サービス概要・能力範囲'
    when 'tech'
      '💻 技術・システム関連'
    when 'project'
      '📋 プロジェクト進行・体制'
    when 'cost', 'pricing'
      '💰 費用・契約'
    when 'case', 'cases'
      '📚 実績・事例'
    when 'consultation'
      '💬 初回相談・問い合わせ'
    when 'integration'
      '🔗 連携・統合'
    when 'support'
      '🎧 サポート'
    else
      category.to_s
    end
  end

  def send_to_slack(webhook_url, payload)
    uri = URI.parse(webhook_url)
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true

    request = Net::HTTP::Post.new(uri.path)
    request['Content-Type'] = 'application/json'
    request.body = payload.to_json

    response = http.request(request)
    
    if response.code == '200'
      Rails.logger.info "Slack notification sent successfully"
      true
    else
      Rails.logger.error "Slack notification failed with status: #{response.code}"
      false
    end
  end
end