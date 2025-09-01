# frozen_string_literal: true

# 人間へのエスカレーションを管理するサービス
class EscalationService
  def initialize
    @slack_notifier = SlackNotifier.new
  end

  # エスカレーションをトリガー
  def trigger_escalation(conversation, metadata)
    # エスカレーション済みチェック
    return { success: false, error: 'Already escalated' } if already_escalated?(metadata)
    
    # エスカレーション情報の準備
    escalation_id = generate_escalation_id
    priority = get_escalation_priority(metadata)
    target_channel = determine_target_channel(metadata['category'])
    
    # Slack通知メッセージの生成
    slack_message = format_slack_message(
      conversation,
      metadata['collected_info'] || {},
      metadata['category'] || 'general'
    )
    
    # 緊急度に応じた追加通知
    if priority == 'high'
      slack_message[:text] = "🚨 緊急エスカレーション\n#{slack_message[:text]}"
    end
    
    # メタデータの更新
    update_conversation_metadata(conversation, escalation_id)
    
    # Slack通知を送信
    slack_result = @slack_notifier.send_notification(target_channel, slack_message)
    
    # 結果を返す
    {
      success: true,
      escalation_id: escalation_id,
      message: 'エスカレーションが正常に実行されました',
      slack_notification: format_notification_text(slack_message, metadata),
      slack_result: slack_result,
      priority: priority,
      target_channel: target_channel,
      notify_channels: priority == 'high' ? ['#urgent-support'] : [],
      notify_users: priority == 'high' ? ['@oncall'] : []
    }
  rescue StandardError => e
    Rails.logger.error "Escalation failed: #{e.message}"
    { success: false, error: e.message }
  end

  # Slack用メッセージのフォーマット
  def format_slack_message(conversation, collected_info, category)
    {
      text: "新規エスカレーション - #{category_label(category)}",
      attachments: [
        {
          color: 'warning',
          title: "#{category_label(category)}案件",
          fields: build_info_fields(collected_info),
          footer: "会話ID: #{conversation.id}",
          ts: Time.current.to_i,
          actions: [
            {
              type: 'button',
              text: '会話履歴を確認',
              url: "#{Rails.application.config.app_url}/conversations/#{conversation.id}"
            }
          ]
        }
      ]
    }
  end

  # エスカレーションが必要か判定
  def should_escalate?(metadata)
    # 既にエスカレーション済みの場合はfalse
    return false if metadata['escalated_at'].present?
    
    # 緊急度が高い
    return true if metadata['urgency'] == 'high'
    
    # 5往復に達した
    return true if (metadata['ai_interaction_count'] || 0) >= 5
    
    # 必要情報が揃った
    if metadata['category'] == 'marketing' && metadata['collected_info']
      required_fields = %w[business_type budget_range current_tools]
      collected_fields = metadata['collected_info'].keys
      return true if (required_fields - collected_fields).empty?
    end
    
    false
  end

  # エスカレーション優先度を取得
  def get_escalation_priority(metadata)
    # 緊急度による判定
    return 'high' if metadata['urgency'] == 'high'
    
    # 予算による判定
    if metadata['collected_info'] && metadata['collected_info']['budget_range']
      budget = metadata['collected_info']['budget_range']
      return 'medium' if budget =~ /(\d+)/ && $1.to_i >= 100
    end
    
    'normal'
  end

  private

  def already_escalated?(metadata)
    metadata['escalation_required'] == true && metadata['escalated_at'].present?
  end

  def generate_escalation_id
    "ESC-#{Time.current.strftime('%Y%m%d')}-#{SecureRandom.hex(4).upcase}"
  end

  def determine_target_channel(category)
    case category
    when 'marketing'
      '#marketing'
    when 'tech'
      '#tech-support'
    else
      '#general-support'
    end
  end

  def category_label(category)
    case category
    when 'marketing'
      'マーケティング'
    when 'tech'
      '技術サポート'
    else
      '一般サポート'
    end
  end

  def build_info_fields(collected_info)
    fields = []
    
    # 業界/事業
    if collected_info['business_type']
      fields << {
        title: '業界/事業',
        value: collected_info['business_type'],
        short: true
      }
    end
    
    # 予算
    if collected_info['budget_range']
      fields << {
        title: '予算',
        value: collected_info['budget_range'],
        short: true
      }
    end
    
    # 利用ツール
    if collected_info['current_tools']
      tools = collected_info['current_tools']
      tools_str = tools.is_a?(Array) ? tools.join(', ') : tools
      fields << {
        title: '利用ツール',
        value: tools_str,
        short: true
      }
    end
    
    # 課題
    if collected_info['challenges']
      fields << {
        title: '課題',
        value: collected_info['challenges'],
        short: false
      }
    end
    
    fields
  end

  def update_conversation_metadata(conversation, escalation_id)
    conversation.metadata ||= {}
    conversation.metadata.merge!({
      'escalation_required' => true,
      'escalated_at' => Time.current.iso8601,
      'escalation_status' => 'pending',
      'escalation_id' => escalation_id
    })
    conversation.save!
  end

  def format_notification_text(slack_message, metadata)
    text = slack_message[:text]
    
    if metadata['collected_info']
      info = metadata['collected_info']
      text += "\n"
      text += "業界: #{info['business_type']}\n" if info['business_type']
      text += "予算: #{info['budget_range']}\n" if info['budget_range']
      text += "課題: #{info['challenges']}\n" if info['challenges']
      text += "エラー: #{info['error_details']}\n" if info['error_details']
      text += "システム: #{info['system_type']}\n" if info['system_type']
    end
    
    text
  end
end