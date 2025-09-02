# frozen_string_literal: true

class SuccessPatternService
  # 成功判定の閾値
  SUCCESS_SCORE_THRESHOLD = 70
  AUTO_SAVE_THRESHOLD = 80
  
  # 成功指標のキーワード
  POSITIVE_INDICATORS = {
    positive_feedback: %w[ありがとう 助かりました 分かりやすい 解決 素晴らしい 良い],
    conversion_intent: %w[契約 購入 導入 申し込み 検討します],
    clear_resolution: %w[解決しました 理解できました 分かりました 了解],
    gratitude_expressed: %w[感謝 お礼 ありがとうございます],
    satisfaction: %w[満足 期待通り 完璧]
  }.freeze
  
  NEGATIVE_INDICATORS = {
    confusion: %w[分からない 理解できない 意味不明 難しい],
    frustration: %w[もういい やめます 諦めます いらない],
    abandonment: %w[さようなら 終了 キャンセル 中止]
  }.freeze
  
  def initialize
    @claude_service = ClaudeApiService.new if defined?(ClaudeApiService)
  end
  
  # 会話を評価
  def evaluate_conversation(conversation)
    messages = extract_messages(conversation)
    indicators = analyze_success_indicators(messages)
    
    # 成功要因の分析
    factors = analyze_factors(messages, indicators)
    score = calculate_success_score(factors)
    
    {
      success_score: score,
      is_successful: score >= SUCCESS_SCORE_THRESHOLD,
      save_recommended: score >= AUTO_SAVE_THRESHOLD,
      indicators: indicators,
      completion_rate: calculate_completion_rate(messages),
      reasoning: extract_reasoning(indicators),
      key_factors: extract_key_factors(factors),
      improvement_areas: score < SUCCESS_SCORE_THRESHOLD ? identify_improvement_areas(messages) : nil
    }
  end
  
  # KnowledgeBaseに保存
  def save_to_knowledge_base(conversation, evaluation)
    content = {
      'messages' => conversation.messages.map do |msg|
        { 'role' => msg.role, 'content' => msg.content }
      end,
      'evaluation' => evaluation
    }
    
    kb = KnowledgeBase.create!(
      conversation: conversation,
      pattern_type: evaluation[:is_successful] ? 'successful_conversation' : 'failed_conversation',
      content: content,
      success_score: evaluation[:success_score],
      metadata: build_metadata(evaluation),
      tags: generate_tags(evaluation),
      summary: generate_summary(conversation)
    )
    
    kb
  end
  
  # 成功パターンを抽出
  def extract_success_patterns(knowledge_base_entry)
    messages = knowledge_base_entry.content['messages'] || []
    
    {
      response_patterns: extract_response_patterns(messages),
      effective_phrases: extract_effective_phrases(messages),
      conversation_flow: analyze_conversation_flow(messages),
      success_triggers: identify_success_triggers(messages),
      templates: generate_templates(messages)
    }
  end
  
  # 高評価の会話を自動保存
  def auto_save_high_rated(conversation)
    # 既に保存済みかチェック
    return nil if KnowledgeBase.exists?(conversation: conversation)
    
    evaluation = evaluate_conversation(conversation)
    
    if evaluation[:save_recommended]
      save_to_knowledge_base(conversation, evaluation)
    end
  end
  
  # 成功指標を分析
  def analyze_success_indicators(messages)
    indicators = []
    
    messages.each do |msg|
      content = msg[:content] || msg['content'] || ''
      
      POSITIVE_INDICATORS.each do |indicator, keywords|
        if keywords.any? { |keyword| content.include?(keyword) }
          indicators << indicator
        end
      end
      
      NEGATIVE_INDICATORS.each do |indicator, keywords|
        if keywords.any? { |keyword| content.include?(keyword) }
          indicators << indicator
        end
      end
    end
    
    indicators.uniq
  end
  
  # 成功スコアを計算
  def calculate_success_score(factors)
    score = 50  # ベーススコア
    
    # ポジティブ要因で加点
    score += 20 if factors[:positive_feedback]
    score += 15 if factors[:goal_achievement]
    score += 15 if factors[:clear_resolution]
    score += 10 if factors[:customer_satisfaction] == 'high'
    score += 10 if factors[:conversion_intent]
    
    # ネガティブ要因で減点（強化）
    score -= 25 if factors[:confusion]
    score -= 30 if factors[:frustration]
    score -= 35 if factors[:abandonment]
    
    # メッセージ数による調整
    if factors[:message_count]
      score += 5 if factors[:message_count].between?(4, 8)
      score -= 10 if factors[:message_count] > 15
    end
    
    # 解決時間による調整
    if factors[:resolution_time]
      score += 5 if factors[:resolution_time] < 10.minutes
      score -= 5 if factors[:resolution_time] > 30.minutes
    end
    
    # 未解決の場合さらに減点
    score -= 15 if !factors[:clear_resolution] && !factors[:positive_feedback]
    
    [score, 100].min.clamp(0, 100)
  end
  
  # 類似パターンを検索
  def find_similar_patterns(current_context, limit: 10)
    query = KnowledgeBase.by_type('successful_conversation')
    
    # タグでフィルタリング - シンプルなアプローチ
    if current_context[:tags] && current_context[:tags].any?
      # 各タグに対してOR条件で検索
      current_context[:tags].each do |tag|
        query = KnowledgeBase.by_type('successful_conversation')
                             .where("'#{tag}' = ANY(tags)")
                             .where('success_score >= ?', 80)
        break if query.exists?  # 最初にマッチしたら使用
      end
    end
    
    # トピックで検索
    if current_context[:topic] && query.empty?
      query = KnowledgeBase.by_type('successful_conversation')
                           .search(current_context[:topic])
                           .where('success_score >= ?', 80)
    end
    
    # 何も見つからない場合は高スコアのものを返す
    if query.empty?
      query = KnowledgeBase.by_type('successful_conversation')
                           .where('success_score >= ?', 80)
    end
    
    query.ordered_by_score.limit(limit)
  end
  
  private
  
  # メッセージを抽出
  def extract_messages(conversation)
    conversation.messages.order(:created_at).map do |msg|
      { role: msg.role, content: msg.content, created_at: msg.created_at }
    end
  end
  
  # 要因を分析
  def analyze_factors(messages, indicators)
    {
      positive_feedback: indicators.include?(:positive_feedback),
      goal_achievement: indicators.include?(:clear_resolution) || indicators.include?(:conversion_intent),
      clear_resolution: indicators.include?(:clear_resolution),
      customer_satisfaction: determine_satisfaction_level(indicators),
      conversion_intent: indicators.include?(:conversion_intent),
      confusion: indicators.include?(:confusion),
      frustration: indicators.include?(:frustration),
      abandonment: indicators.include?(:abandonment),
      message_count: messages.size,
      resolution_time: calculate_resolution_time(messages)
    }
  end
  
  # 完了率を計算
  def calculate_completion_rate(messages)
    return 0.0 if messages.empty?
    
    # 最後のメッセージがポジティブな終了か
    last_message = messages.last[:content] || ''
    
    if POSITIVE_INDICATORS.values.flatten.any? { |word| last_message.include?(word) }
      return 1.0
    elsif NEGATIVE_INDICATORS.values.flatten.any? { |word| last_message.include?(word) }
      return 0.3
    else
      return 0.7
    end
  end
  
  # 理由を抽出
  def extract_reasoning(indicators)
    reasoning = {}
    
    reasoning[:customer_satisfaction] = true if indicators.include?(:positive_feedback)
    reasoning[:goal_achievement] = true if indicators.include?(:clear_resolution)
    reasoning[:conversion_potential] = true if indicators.include?(:conversion_intent)
    
    reasoning
  end
  
  # 主要要因を抽出
  def extract_key_factors(factors)
    key_factors = []
    
    key_factors << '適切な提案' if factors[:goal_achievement]
    key_factors << 'ニーズの把握' if factors[:clear_resolution]
    key_factors << '顧客満足' if factors[:customer_satisfaction] == 'high'
    key_factors << '迅速な対応' if factors[:resolution_time] && factors[:resolution_time] < 10.minutes
    
    key_factors
  end
  
  # 改善点を特定
  def identify_improvement_areas(messages)
    areas = []
    
    areas << '応答の明確化' if messages.any? { |m| m[:content].include?('分からない') }
    areas << '説明の簡潔化' if messages.size > 15
    areas << '顧客ニーズの把握' if messages.none? { |m| m[:content].include?('解決') }
    
    areas
  end
  
  # メタデータを構築
  def build_metadata(evaluation)
    {
      'indicators' => (evaluation[:indicators] || []).map(&:to_s),
      'reasoning' => evaluation[:reasoning],
      'completion_rate' => evaluation[:completion_rate],
      'evaluated_at' => Time.current.to_s
    }
  end
  
  # タグを生成
  def generate_tags(evaluation)
    tags = []
    indicators = evaluation[:indicators] || []
    
    tags << 'high_score' if evaluation[:success_score] >= 80
    # satisfaction指標もチェック
    tags << 'customer_satisfaction' if indicators.include?(:positive_feedback) || indicators.include?(:satisfaction) || indicators.include?(:clear_resolution)
    tags << 'conversion' if indicators.include?(:conversion_intent)
    tags << 'successful' if evaluation[:is_successful]
    
    tags
  end
  
  # 要約を生成
  def generate_summary(conversation)
    messages = conversation.messages.order(:created_at)
    key_points = []
    
    messages.each do |msg|
      if msg.content =~ /導入|検討/
        key_points << '導入検討'
      end
      if msg.content =~ /データ分析|分析機能/
        key_points << 'データ分析'
      end
      if msg.content =~ /エンタープライズ|プラン/
        key_points << 'エンタープライズプラン'
      end
    end
    
    key_points.uniq.join('、')
  end
  
  # 満足度レベルを判定
  def determine_satisfaction_level(indicators)
    positive_count = (indicators & POSITIVE_INDICATORS.keys).size
    negative_count = (indicators & NEGATIVE_INDICATORS.keys).size
    
    return 'high' if positive_count >= 2 && negative_count == 0
    return 'low' if negative_count >= 2
    'medium'
  end
  
  # 解決時間を計算
  def calculate_resolution_time(messages)
    return nil if messages.size < 2
    
    first_time = messages.first[:created_at]
    last_time = messages.last[:created_at]
    
    return nil unless first_time && last_time
    
    last_time - first_time
  end
  
  # 応答パターンを抽出
  def extract_response_patterns(messages)
    patterns = []
    
    messages.each_cons(2) do |user_msg, assistant_msg|
      next unless user_msg['role'] == 'user' && assistant_msg['role'] == 'assistant'
      
      if user_msg['content'].include?('検討')
        patterns << { trigger: '検討', response: assistant_msg['content'] }
      end
    end
    
    patterns
  end
  
  # 効果的なフレーズを抽出
  def extract_effective_phrases(messages)
    phrases = []
    
    messages.each do |msg|
      next unless msg['role'] == 'assistant'
      
      content = msg['content']
      phrases << content if content.include?('おすすめ')
      phrases << content if content.include?('最適')
    end
    
    phrases
  end
  
  # 会話フローを分析
  def analyze_conversation_flow(messages)
    {
      total_messages: messages.size,
      user_messages: messages.count { |m| m['role'] == 'user' },
      assistant_messages: messages.count { |m| m['role'] == 'assistant' },
      average_response_length: calculate_average_length(messages)
    }
  end
  
  # 成功トリガーを特定
  def identify_success_triggers(messages)
    triggers = []
    
    messages.each_cons(2) do |msg1, msg2|
      if msg2['content'].include?('ありがとう')
        triggers << msg1['content']
      end
    end
    
    triggers
  end
  
  # テンプレートを生成
  def generate_templates(messages)
    templates = []
    
    messages.each_cons(2) do |user_msg, assistant_msg|
      next unless user_msg['role'] == 'user' && assistant_msg['role'] == 'assistant'
      
      template = {
        trigger: extract_trigger_pattern(user_msg['content']),
        response: extract_response_template(assistant_msg['content']),
        context: 'general'
      }
      
      templates << template
    end
    
    templates.first(3)  # 最初の3つのみ返す
  end
  
  # トリガーパターンを抽出
  def extract_trigger_pattern(content)
    # 簡略化のため、最初の10文字を返す
    content[0..9] + '...'
  end
  
  # 応答テンプレートを抽出
  def extract_response_template(content)
    # 簡略化のため、最初の20文字を返す
    content[0..19] + '...'
  end
  
  # 平均長を計算
  def calculate_average_length(messages)
    assistant_messages = messages.select { |m| m['role'] == 'assistant' }
    return 0 if assistant_messages.empty?
    
    total_length = assistant_messages.sum { |m| m['content'].length }
    total_length / assistant_messages.size
  end
end