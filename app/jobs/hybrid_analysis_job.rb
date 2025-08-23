# frozen_string_literal: true

# NeedsExtractorを使用したハイブリッド分析ジョブ
class HybridAnalysisJob < ApplicationJob
  queue_as :default

  def perform(conversation_id)
    conversation = Conversation.find(conversation_id)
    
    # 会話履歴を構築
    conversation_history = build_conversation_history(conversation)
    
    # NeedsExtractorで分析
    extractor = NeedsExtractor.new
    extracted_needs = extractor.extract_needs(conversation_history)
    
    # 分析結果を保存
    analysis = save_analysis(conversation, extracted_needs)
    
    # リアルタイム配信
    broadcast_analysis_result(conversation, analysis)
    
    # 高優先度の場合はエスカレーション
    handle_escalation(conversation, analysis) if requires_escalation?(extracted_needs)
    
    Rails.logger.info "Analysis completed for conversation ##{conversation.id}"
  rescue StandardError => e
    Rails.logger.error "Analysis failed for conversation ##{conversation.id}: #{e.message}"
    Rails.logger.error e.backtrace.join("\n") if e.backtrace
    
    # フォールバック分析を保存
    save_fallback_analysis(conversation)
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

  def save_analysis(conversation, extracted_needs)
    # 既存の分析を更新または新規作成
    analysis = conversation.analyses.find_or_initialize_by(
      analysis_type: 'needs'
    )
    
    # 分析データを構築
    analysis_data = build_analysis_data(extracted_needs)
    
    # 最高優先度と感情を決定
    priority_level = determine_overall_priority(extracted_needs)
    sentiment = determine_overall_sentiment(extracted_needs)
    confidence_score = calculate_average_confidence(extracted_needs)
    
    analysis.update!(
      analysis_data: analysis_data,
      hidden_needs: analysis_data[:hidden_needs],
      priority_level: priority_level,
      sentiment: sentiment,
      confidence_score: confidence_score,
      analyzed_at: Time.current
    )
    
    analysis
  end

  def build_analysis_data(extracted_needs)
    {
      hidden_needs: extracted_needs.map do |need|
        {
          'need_type' => need[:type].to_s,
          'evidence' => need[:evidence],
          'confidence' => need[:confidence],
          'proactive_suggestion' => need[:suggestion],
          'priority' => need[:priority],
          'priority_score' => need[:priority_score]
        }
      end,
      extraction_method: 'pattern_matching',
      analyzed_at: Time.current.iso8601
    }
  end

  def determine_overall_priority(extracted_needs)
    return 'low' if extracted_needs.empty?
    
    priorities = extracted_needs.map { |n| n[:priority] }
    
    if priorities.include?('high')
      'high'
    elsif priorities.include?('medium')
      'medium'
    else
      'low'
    end
  end

  def determine_overall_sentiment(extracted_needs)
    # 感情ブーストがあるニーズをチェック
    boosted_needs = extracted_needs.select { |n| n[:priority_boost].to_i.positive? }
    
    if boosted_needs.any? { |n| n[:priority_boost].to_i >= 2 }
      'frustrated'
    elsif boosted_needs.any?
      'negative'
    else
      'neutral'
    end
  end

  def calculate_average_confidence(extracted_needs)
    return 0.0 if extracted_needs.empty?
    
    total_confidence = extracted_needs.sum { |n| n[:confidence] }
    (total_confidence / extracted_needs.length).round(2)
  end

  def broadcast_analysis_result(conversation, analysis)
    ActionCable.server.broadcast(
      "conversation_#{conversation.id}",
      {
        type: 'analysis_complete',
        analysis: {
          hidden_needs: analysis.hidden_needs,
          sentiment: analysis.sentiment,
          priority: analysis.priority_level,
          confidence_score: analysis.confidence_score,
          extraction_method: 'pattern_matching'
        }
      }
    )
  end

  def requires_escalation?(extracted_needs)
    extracted_needs.any? { |n| n[:priority] == 'high' && n[:priority_boost].to_i >= 2 }
  end

  def handle_escalation(conversation, analysis)
    # エスカレーション記録
    analysis.escalate!
    
    # 通知送信（EscalationNotifierが存在する場合）
    if defined?(EscalationNotifier)
      summary = build_escalation_summary(analysis)
      
      # Slack通知
      EscalationNotifier.to_slack(
        build_slack_message(conversation, analysis),
        channel: '#support-escalations'
      )
      
      # メール通知
      if defined?(EscalationMailer)
        EscalationMailer.alert(
          conversation_id: conversation.id,
          summary: summary
        ).deliver_later
      end
    end
    
    Rails.logger.info "Escalation triggered for conversation ##{conversation.id}"
  end

  def build_escalation_summary(analysis)
    needs = analysis.hidden_needs.first(3).pluck('proactive_suggestion').join(', ')
    "優先度: #{analysis.priority_level}, 感情: #{analysis.sentiment}, 推奨: #{needs}"
  end

  def build_slack_message(conversation, analysis)
    <<~MESSAGE
      🚨 エスカレーションが必要な会話を検出
      
      会話ID: ##{conversation.id}
      ユーザー: #{conversation.user.name}
      優先度: #{analysis.priority_level}
      感情: #{analysis.sentiment}
      
      検出されたニーズ:
      #{format_needs(analysis.hidden_needs)}
      
      URL: #{conversation_url(conversation)}
    MESSAGE
  end

  def format_needs(needs)
    needs.first(3).map do |need|
      "• #{need['need_type']}: #{need['evidence']} (信頼度: #{(need['confidence'] * 100).round}%)"
    end.join("\n")
  end

  def conversation_url(conversation)
    "http://localhost:3000/conversations/#{conversation.id}"
  end

  def save_fallback_analysis(conversation)
    conversation.analyses.create!(
      analysis_type: 'needs',
      analysis_data: {
        error: true,
        message: 'Analysis failed, fallback data saved',
        hidden_needs: []
      },
      priority_level: 'low',
      sentiment: 'neutral',
      confidence_score: 0.0,
      analyzed_at: Time.current
    )
  end
end