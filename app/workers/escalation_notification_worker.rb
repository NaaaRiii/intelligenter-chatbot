# frozen_string_literal: true

# エスカレーション通知を処理するワーカー
class EscalationNotificationWorker
  include Sidekiq::Worker

  sidekiq_options queue: 'critical',
                  retry: 10,
                  backtrace: 20

  def perform(analysis_id, options = {})
    Rails.logger.info "Processing escalation notification for analysis ##{analysis_id}"

    analysis = Analysis.find(analysis_id)
    # テストの手動トリガや明示的な通知要求では強制的に通知する
    force_notify = options.is_a?(Hash) ? (options['force'] || options[:force]) : false
    return unless force_notify || analysis.requires_escalation?

    # optionsからチャネルを取得、デフォルトは'all'
    notification_type = options.is_a?(Hash) ? (options['channel'] || options[:channel] || 'all') : (options || 'all')

    # 通知タイプに応じて処理を分岐
    case notification_type
    when 'email'
      send_email_notification(analysis)
    when 'slack'
      send_slack_notification(analysis)
    when 'dashboard'
      update_dashboard(analysis)
    when 'all'
      send_email_notification(analysis)
      send_slack_notification(analysis)
      update_dashboard(analysis)
    end

    # エスカレーション済みとしてマーク
    analysis.escalate! unless analysis.escalated?

    Rails.logger.info "Completed escalation notification for analysis ##{analysis_id}"
  rescue ActiveRecord::RecordNotFound => e
    Rails.logger.error "Analysis not found: #{e.message}"
    # レコードが見つからない場合はリトライしない
  rescue StandardError => e
    Rails.logger.error "Escalation notification failed: #{e.message}"
    Rails.logger.error e.backtrace.join("\n")
    raise # リトライさせる
  end

  private

  def send_email_notification(analysis)
    # メール通知の実装（将来的に実装）
    Rails.logger.info "Email notification would be sent for analysis ##{analysis.id}"
    # EscalationMailer.notify(analysis).deliver_later
  end

  def send_slack_notification(analysis)
    # Slack通知の実装
    return unless ENV['SLACK_WEBHOOK_URL'].present?

    slack_message = build_slack_message(analysis)

    # 期待されるログ出力（テストが参照）
    Rails.logger.info "Sending Slack notification for analysis ##{analysis.id}"
    # 追加情報はdebugで出力（変数参照を維持）
    Rails.logger.debug { "Slack payload: #{slack_message.to_json}" }

    # Slack WebhookへPOST
    if ENV['SLACK_WEBHOOK_URL'].present?
      require 'net/http'
      require 'uri'
      
      uri = URI(ENV['SLACK_WEBHOOK_URL'])
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true
      
      request = Net::HTTP::Post.new(uri)
      request['Content-Type'] = 'application/json'
      request.body = slack_message.to_json
      
      response = http.request(request)
      Rails.logger.info "Slack notification sent with status: #{response.code}"
    end
  end

  def update_dashboard(analysis)
    # ダッシュボードへのリアルタイム更新
    ActionCable.server.broadcast(
      'escalation_channel',
      {
        type: 'new_escalation',
        analysis_id: analysis.id,
        conversation_id: analysis.conversation_id,
        priority: analysis.priority_level,
        sentiment: analysis.sentiment,
        reasons: analysis.escalation_reasons,
        timestamp: Time.current.iso8601
      }
    )
  end

  def build_slack_message(analysis)
    conversation = analysis.conversation
    user = conversation.user

    {
      text: "⚠️ エスカレーションが必要な会話を検出しました",
      attachments: [
        {
          color: priority_color(analysis.priority_level),
          fields: [
            {
              title: "会話ID",
              value: conversation.id,
              short: true
            },
            {
              title: "ユーザー",
              value: user&.email || 'Unknown',
              short: true
            },
            {
              title: "優先度",
              value: analysis.priority_level,
              short: true
            },
            {
              title: "感情状態",
              value: analysis.sentiment,
              short: true
            },
            {
              title: "エスカレーション理由",
              value: analysis.escalation_reasons || 'N/A',
              short: false
            },
            {
              title: "信頼度スコア",
              value: analysis.confidence_score ? "#{(analysis.confidence_score * 100).round}%" : "N/A",
              short: true
            }
          ],
          footer: "Intelligent Chatbot System",
          ts: Time.current.to_i
        }
      ]
    }
  end

  def priority_color(priority_level)
    case priority_level
    when 'urgent'
      'danger'  # 赤
    when 'high'
      'warning' # オレンジ
    when 'medium'
      '#36a64f' # 緑
    else
      'good'    # グレー
    end
  end
end