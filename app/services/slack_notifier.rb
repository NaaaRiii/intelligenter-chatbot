# frozen_string_literal: true

require 'net/http'
require 'json'

# Slack通知を管理するサービス
class SlackNotifier
  # Webhook URLの設定（環境変数から取得）
  WEBHOOK_URLS = {
    '#marketing' => ENV['SLACK_MARKETING_WEBHOOK_URL'],
    '#tech-support' => ENV['SLACK_TECH_WEBHOOK_URL'],
    '#general-support' => ENV['SLACK_GENERAL_WEBHOOK_URL'],
    '#urgent-support' => ENV['SLACK_URGENT_WEBHOOK_URL']
  }.freeze

  # デフォルトのWebhook URL
  DEFAULT_WEBHOOK_URL = ENV['SLACK_DEFAULT_WEBHOOK_URL'] || ENV['SLACK_GENERAL_WEBHOOK_URL']

  def initialize
    @timeout = 10 # seconds
  end

  # Slackに通知を送信
  def send_notification(channel, message)
    webhook_url = get_webhook_url(channel)
    
    return { success: false, error: 'Webhook URL not configured' } unless webhook_url
    
    begin
      response = post_to_slack(webhook_url, message)
      
      if response.code == '200' && response.body == 'ok'
        { success: true, response: response.body }
      else
        { success: false, error: response.body || "HTTP #{response.code}" }
      end
    rescue Net::OpenTimeout, Net::ReadTimeout => e
      { success: false, error: "Request timeout: #{e.message}" }
    rescue StandardError => e
      { success: false, error: e.message }
    end
  end

  # エスカレーション用のメッセージをフォーマット
  def format_escalation_message(escalation_data)
    priority = escalation_data[:priority] || 'normal'
    category = escalation_data[:category] || 'general'
    collected_info = escalation_data[:collected_info] || {}
    
    # 優先度に応じたプレフィックス
    prefix = case priority
             when 'high' then '🚨 緊急'
             when 'medium' then '⚠️ 要対応'
             else '📋'
             end
    
    # カテゴリラベル
    category_label = case category
                     when 'marketing' then 'マーケティング'
                     when 'tech' then '技術サポート'
                     else '一般サポート'
                     end
    
    {
      text: "#{prefix} 新規エスカレーション",
      attachments: [
        {
          title: "#{category_label}案件",
          color: priority == 'high' ? 'danger' : 'warning',
          fields: build_fields(collected_info),
          footer: "ID: #{escalation_data[:conversation_id]}",
          ts: Time.current.to_i,
          actions: [
            {
              type: 'button',
              text: 'ダッシュボードで確認',
              url: "#{Rails.application.config.app_url}/dashboard"
            }
          ]
        }
      ]
    }
  end

  # 接続テスト
  def test_connection(channel)
    webhook_url = get_webhook_url(channel)
    
    return { success: false, message: 'Webhook URLが設定されていません' } unless webhook_url
    
    test_message = { text: 'Connection test' }
    
    begin
      response = post_to_slack(webhook_url, test_message)
      
      if response.code == '200' && response.body == 'ok'
        { success: true, message: '正常に接続できました' }
      else
        { success: false, message: "無効なWebhook URL: #{response.body}" }
      end
    rescue StandardError => e
      { success: false, message: "接続エラー: #{e.message}" }
    end
  end

  private

  def get_webhook_url(channel)
    # チャンネル名からWebhook URLを取得
    url = WEBHOOK_URLS[channel] || DEFAULT_WEBHOOK_URL
    
    # テスト環境では固定URLを返す（実際のSlackに送信しない）
    if Rails.env.test?
      return "https://hooks.slack.com/services/test/#{channel.gsub('#', '')}/test"
    end
    
    url
  end

  def post_to_slack(webhook_url, message)
    uri = URI.parse(webhook_url)
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    http.open_timeout = @timeout
    http.read_timeout = @timeout
    
    request = Net::HTTP::Post.new(uri.request_uri)
    request['Content-Type'] = 'application/json'
    request.body = message.to_json
    
    http.request(request)
  end

  def build_fields(collected_info)
    fields = []
    
    # 各情報をフィールドとして追加
    collected_info.each do |key, value|
      next if value.nil? || value.empty?
      
      field_title = case key
                     when 'business_type' then '業界/事業'
                     when 'budget_range' then '予算'
                     when 'current_tools' then '利用ツール'
                     when 'challenges' then '課題'
                     when 'timeline' then '期限'
                     else key.humanize
                     end
      
      field_value = value.is_a?(Array) ? value.join(', ') : value.to_s
      
      fields << {
        title: field_title,
        value: field_value,
        short: key != 'challenges' # 課題は長文の可能性があるので全幅表示
      }
    end
    
    fields
  end
end