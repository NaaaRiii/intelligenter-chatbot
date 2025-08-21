class AnalyzeConversationJob < ApplicationJob
  queue_as :analysis

  def perform(conversation_id)
    conversation = Conversation.find(conversation_id)
    return unless conversation

    messages = conversation.messages.chronological
    return if messages.empty?

    analysis = create_analysis(conversation, messages)
    handle_escalation(conversation, analysis)
    broadcast_analysis_result(conversation, analysis)
  rescue StandardError => e
    Rails.logger.error "Analysis Error: #{e.message}"
  end

  private

  def perform_analysis(messages)
    # TODO: 実際のAI分析APIを呼び出す
    # ここでは仮の分析結果を返す
    {
      hidden_needs: extract_hidden_needs(messages),
      sentiment: analyze_sentiment(messages),
      topics: extract_topics(messages),
      urgency_level: calculate_urgency(messages),
      confidence_score: 0.85,
      evidence_quotes: extract_key_phrases(messages)
    }
  end

  def extract_hidden_needs(messages)
    # 仮実装：メッセージから隠れたニーズを抽出
    needs = []

    messages.each do |msg|
      content = msg.content.downcase
      analyze_content_for_needs(content, needs)
    end

    needs.uniq
  end

  def analyze_content_for_needs(content, needs)
    needs << { type: 'efficiency', confidence: 0.9 } if efficiency_needed?(content)
    needs << { type: 'cost_optimization', confidence: 0.8 } if cost_optimization_needed?(content)
    needs << { type: 'automation', confidence: 0.85 } if automation_needed?(content)
  end

  def efficiency_needed?(content)
    content.include?('遅い') || content.include?('時間')
  end

  def cost_optimization_needed?(content)
    content.include?('高い') || content.include?('料金')
  end

  def automation_needed?(content)
    content.include?('自動') || content.include?('手間')
  end

  def analyze_sentiment(messages)
    # 仮実装：感情分析
    counts = count_sentiment_words(messages)
    calculate_sentiment_result(counts, messages.count)
  end

  def count_sentiment_words(messages)
    positive_words = %w[ありがとう 素晴らしい 良い 便利 助かる]
    negative_words = %w[困る 問題 エラー 不便 遅い]

    counts = { positive: 0, negative: 0 }

    messages.each do |msg|
      content = msg.content
      counts[:positive] += positive_words.count { |word| content.include?(word) }
      counts[:negative] += negative_words.count { |word| content.include?(word) }
    end

    counts
  end

  def calculate_sentiment_result(counts, message_count)
    overall = determine_overall_sentiment(counts[:positive], counts[:negative])

    {
      overall: overall,
      positive_score: counts[:positive].to_f / message_count,
      negative_score: counts[:negative].to_f / message_count
    }
  end

  def determine_overall_sentiment(positive_count, negative_count)
    if positive_count > negative_count
      'positive'
    elsif negative_count > positive_count
      'negative'
    else
      'neutral'
    end
  end

  def extract_topics(_messages)
    # 仮実装：トピック抽出
    %w[技術的問題 料金相談 機能要望 使い方]
  end

  def extract_key_phrases(messages)
    # 仮実装：重要フレーズ抽出
    messages.last(3).map(&:content).pluck(0..50)
  end

  def calculate_urgency(messages)
    # 仮実装：緊急度計算
    urgent_keywords = %w[至急 緊急 すぐに 今すぐ エラー 動かない]

    urgent_count = messages.sum do |msg|
      urgent_keywords.count { |keyword| msg.content.include?(keyword) }
    end

    urgent_count > 2 ? 'high' : 'normal'
  end

  def determine_priority(analysis_result)
    case analysis_result[:urgency_level]
    when 'high'
      'high'
    when 'normal'
      analysis_result[:sentiment][:overall] == 'negative' ? 'medium' : 'low'
    else
      'low'
    end
  end

  def should_escalate?(analysis_result)
    analysis_result[:urgency_level] == 'high' ||
      analysis_result[:sentiment][:overall] == 'negative'
  end

  def notify_escalation(conversation, _analysis)
    # TODO: エスカレーション通知を実装
    Rails.logger.info "Escalation needed for conversation #{conversation.id}"
  end

  def broadcast_analysis_result(conversation, analysis)
    ActionCable.server.broadcast(
      "conversation_#{conversation.id}",
      {
        type: 'analysis_complete',
        analysis: {
          id: analysis.id,
          type: analysis.analysis_type,
          priority: analysis.priority_level,
          sentiment: analysis.sentiment,
          hidden_needs: analysis.hidden_needs,
          created_at: analysis.created_at
        }
      }
    )
  end

  def create_analysis(conversation, messages)
    analysis_result = perform_analysis(messages)

    conversation.analyses.create!(
      analysis_type: 'pattern',
      analysis_data: analysis_result,
      priority_level: determine_priority(analysis_result),
      sentiment: analysis_result[:sentiment][:overall],
      escalated: should_escalate?(analysis_result)
    )
  end

  def handle_escalation(conversation, analysis)
    return unless analysis.needs_escalation?

    analysis.escalate!
    notify_escalation(conversation, analysis)
  end
end
