# frozen_string_literal: true

# 問い合わせ内容を分析して構造化データを抽出
class InquiryAnalyzerService
  CATEGORIES = {
    'marketing' => %w[広告 マーケティング 集客 SEO リード CVR ROI],
    'tech' => %w[システム 開発 API 連携 データベース インフラ],
    'sales' => %w[営業 商談 提案 見積 契約 価格],
    'support' => %w[サポート 不具合 エラー 使い方 設定],
    'consultation' => %w[相談 検討 導入 比較]
  }.freeze

  URGENCY_KEYWORDS = {
    high: %w[至急 緊急 今すぐ 本日中 明日まで ASAP],
    medium: %w[今週 近日中 早めに なるべく早く],
    low: %w[検討中 将来的に いずれ 参考程度]
  }.freeze

  INTENT_PATTERNS = {
    information_gathering: %w[教えて 知りたい 確認したい どうなって],
    problem_solving: %w[できない エラー 動かない 困って 解決],
    comparison: %w[比較 違い どちら 他社],
    pricing: %w[料金 費用 価格 見積 予算],
    implementation: %w[導入 実装 開始 始めたい]
  }.freeze

  def analyze(message, conversation_history = [])
    {
      category: detect_category(message),
      intent: detect_intent(message),
      urgency: detect_urgency(message),
      keywords: extract_keywords(message),
      entities: extract_entities(message),
      sentiment: analyze_sentiment(message),
      customer_profile: build_customer_profile(conversation_history),
      required_info: identify_missing_info(message, conversation_history),
      next_action: suggest_next_action(message)
    }
  end

  private

  def detect_category(message)
    CATEGORIES.each do |category, keywords|
      return category if keywords.any? { |keyword| message.include?(keyword) }
    end
    'general'
  end

  def detect_intent(message)
    INTENT_PATTERNS.each do |intent, patterns|
      return intent.to_s if patterns.any? { |pattern| message.include?(pattern) }
    end
    'general_inquiry'
  end

  def detect_urgency(message)
    URGENCY_KEYWORDS.each do |level, keywords|
      return level.to_s if keywords.any? { |keyword| message.include?(keyword) }
    end
    'normal'
  end

  def extract_keywords(message)
    # 重要なキーワードを抽出（簡易版）
    keywords = []
    
    # 技術用語
    tech_terms = %w[React Vue Angular Node Ruby Rails Python Django Go AWS GCP Docker Kubernetes]
    keywords += tech_terms.select { |term| message.include?(term) }
    
    # ビジネス用語
    business_terms = %w[EC BtoB BtoC SaaS CRM MA CDP DX ROI KPI CVR CPA]
    keywords += business_terms.select { |term| message.include?(term) }
    
    keywords.uniq
  end

  def extract_entities(message)
    entities = {}
    
    # 予算の抽出
    if message =~ /(\d+)万円|(\d+)千円|(\d+)円/
      entities[:budget] = Regexp.last_match[0]
    end
    
    # 期間の抽出
    if message =~ /(\d+)ヶ月|(\d+)週間|(\d+)日/
      entities[:timeline] = Regexp.last_match[0]
    end
    
    # 規模の抽出
    if message =~ /(\d+)人|(\d+)名|(\d+)社/
      entities[:scale] = Regexp.last_match[0]
    end
    
    entities
  end

  def analyze_sentiment(message)
    positive_words = %w[良い 素晴らしい 期待 嬉しい 満足 楽しみ]
    negative_words = %w[困って 不満 問題 エラー できない 悪い 遅い]
    
    positive_score = positive_words.count { |word| message.include?(word) }
    negative_score = negative_words.count { |word| message.include?(word) }
    
    if positive_score > negative_score
      'positive'
    elsif negative_score > positive_score
      'negative'
    else
      'neutral'
    end
  end

  def build_customer_profile(conversation_history)
    profile = {
      industry: nil,
      company_size: nil,
      main_challenges: [],
      budget_range: nil,
      decision_timeline: nil
    }
    
    # 会話履歴から情報を抽出
    conversation_history.each do |message|
      content = message[:content] || message['content']
      
      # 業界の推定
      if content =~ /小売|EC|アパレル|食品|製造|金融|不動産|医療|教育/
        profile[:industry] ||= Regexp.last_match[0]
      end
      
      # 規模の推定
      if content =~ /(\d+)人規模|従業員(\d+)名/
        profile[:company_size] ||= Regexp.last_match[0]
      end
      
      # 課題の抽出
      if content =~ /課題|問題|困って|改善したい/
        profile[:main_challenges] << content[0..100]
      end
    end
    
    profile
  end

  def identify_missing_info(message, conversation_history)
    required = []
    collected_info = extract_collected_info(conversation_history)
    
    # カテゴリによって必要な情報を判定
    category = detect_category(message)
    
    case category
    when 'marketing'
      required << 'current_marketing_channels' unless collected_info[:channels]
      required << 'monthly_budget' unless collected_info[:budget]
      required << 'target_metrics' unless collected_info[:kpi]
    when 'tech'
      required << 'current_tech_stack' unless collected_info[:tech_stack]
      required << 'team_size' unless collected_info[:team_size]
      required << 'integration_requirements' unless collected_info[:integrations]
    when 'sales'
      required << 'sales_cycle' unless collected_info[:sales_cycle]
      required << 'average_deal_size' unless collected_info[:deal_size]
      required << 'target_customers' unless collected_info[:target]
    end
    
    required
  end

  def extract_collected_info(conversation_history)
    info = {}
    
    conversation_history.each do |message|
      content = message[:content] || message['content']
      
      info[:budget] = true if content =~ /予算|万円/
      info[:timeline] = true if content =~ /期限|いつまで|ヶ月/
      info[:tech_stack] = true if content =~ /使って|利用して|システム/
      info[:team_size] = true if content =~ /チーム|人数|メンバー/
    end
    
    info
  end

  def suggest_next_action(message)
    intent = detect_intent(message)
    urgency = detect_urgency(message)
    
    if urgency == 'high'
      'immediate_escalation'
    elsif intent == 'pricing'
      'send_pricing_info'
    elsif intent == 'problem_solving'
      'technical_support'
    elsif intent == 'comparison'
      'send_comparison_sheet'
    else
      'continue_conversation'
    end
  end
end