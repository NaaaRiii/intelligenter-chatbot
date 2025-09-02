# frozen_string_literal: true

class TopicDeviationService
  # 話題の逸脱を検知する閾値
  DEVIATION_THRESHOLD = 0.6  # 閾値を下げてより敏感に
  TOPIC_RELEVANCE_THRESHOLD = 0.3
  
  # 話題のカテゴリ定義
  TOPIC_CATEGORIES = {
    business: %w[料金 プラン 機能 導入 契約 サポート 事例 比較 見積もり デモ],
    personal: %w[好き 嫌い 年齢 趣味 性格 私生活 個人的],
    off_topic: %w[天気 ニュース スポーツ 芸能 政治 食事 旅行],
    technical: %w[実装 API 連携 セキュリティ データ バックアップ 移行],
    greeting: %w[こんにちは ありがとう よろしく お願い 失礼]
  }.freeze
  
  def initialize
    @context_service = ConversationContextService.new
  end
  
  # 話題の逸脱を検出
  def detect_deviation(message:, conversation:)
    context = @context_service.build_context(conversation)
    main_topic = identify_main_topic(context)
    message_topic = extract_message_topic(message)
    
    # 話題間の距離を計算
    distance = calculate_topic_distance(main_topic, message_topic)
    
    # 逸脱の判定
    deviated = distance > DEVIATION_THRESHOLD
    deviation_type = determine_deviation_type(message, message_topic) if deviated
    
    {
      deviated: deviated,
      deviation_type: deviation_type,
      main_topic: main_topic,
      current_topic: message_topic,
      confidence: calculate_confidence(distance),
      topic_relevance: 1.0 - distance,
      severity: deviated ? calculate_severity(deviation_type) : nil,
      suggested_redirect: deviated ? generate_redirect_suggestion(main_topic) : nil,
      is_transition: is_transition_phrase?(message),
      continuation_type: deviated ? nil : determine_continuation_type(message, context)
    }
  end
  
  # 軌道修正の提案を生成
  def suggest_redirect(deviation_context)
    main_topic = deviation_context[:main_topic]
    deviation_type = deviation_context[:deviation_type]
    
    options = generate_redirect_options(main_topic, deviation_type)
    
    {
      redirect_message: build_redirect_message(main_topic),
      transition_phrase: select_transition_phrase(deviation_type),
      maintain_politeness: true,
      options: options,
      recommended_option: options.first
    }
  end
  
  # 話題間の距離を計算
  def calculate_topic_distance(topic1, topic2)
    return 0.0 if topic1 == topic2
    
    # 直接類似度をチェック
    if (topic1.include?('料金') && topic2.include?('価格')) ||
       (topic1.include?('価格') && topic2.include?('料金')) ||
       (topic1.include?('プラン') && topic2.include?('設定'))
      return 0.2
    end
    
    # 同じカテゴリ内の話題は距離が近い
    cat1 = find_topic_category(topic1)
    cat2 = find_topic_category(topic2)
    
    if cat1 && cat2
      return 0.2 if cat1 == cat2
      return 0.5 if related_categories?(cat1, cat2)
    end
    
    # キーワードの重複をチェック
    keywords1 = extract_keywords(topic1)
    keywords2 = extract_keywords(topic2)
    
    overlap = (keywords1 & keywords2).size
    total = [keywords1.size, keywords2.size].max
    
    return 1.0 if total == 0  # キーワードがない場合は完全に異なる
    
    similarity = overlap.to_f / total
    1.0 - similarity
  end
  
  # 会話の目的を特定
  def identify_conversation_goal(messages)
    # メッセージ内容から意図を分析
    intents = messages.map { |msg| analyze_intent(msg[:content]) if msg[:role] == 'user' }.compact
    topics = messages.flat_map { |msg| extract_keywords(msg[:content]) }.uniq
    
    primary_intent = intents.max_by { |intent| intents.count(intent) }
    stage = determine_conversation_stage(messages)
    
    {
      primary_intent: primary_intent || 'general_inquiry',
      key_topics: categorize_topics(topics),
      stage: stage,
      confidence: calculate_goal_confidence(intents, topics)
    }
  end
  
  # 軌道修正の応答を生成
  def generate_redirect_response(context_info)
    main_topic = context_info[:main_topic]
    deviation_type = context_info[:deviation_type]
    severity = context_info[:severity] || calculate_severity(deviation_type)
    
    tone = select_tone(severity, deviation_type)
    message = build_response_message(main_topic, deviation_type, tone)
    
    {
      message: message,
      tone: tone,
      includes_acknowledgment: should_acknowledge?(deviation_type),
      maintains_relationship: true,
      offers_alternative: should_offer_alternative?(deviation_type)
    }
  end
  
  # 逸脱パターンを追跡
  def track_deviation_patterns(conversation:, deviations:)
    return {} if deviations.empty?
    
    # 逸脱タイプの頻度を計算
    type_counts = deviations.group_by { |d| d[:type] }.transform_values(&:count)
    frequent_type = type_counts.max_by { |_, count| count }&.first
    
    # 逸脱率を計算
    total_messages = conversation.messages.count
    deviation_rate = deviations.size.to_f / total_messages
    
    # ユーザーの混乱を判定
    confusion = deviation_rate > 0.3 || type_counts.size > 2
    
    {
      frequent_deviation_type: frequent_type,
      deviation_rate: deviation_rate,
      suggests_user_confusion: confusion,
      recommended_action: recommend_action(deviation_rate, confusion)
    }
  end
  
  private
  
  # メイントピックを特定
  def identify_main_topic(context)
    return 'general' unless context[:key_points]
    
    # 会話履歴から最も頻繁に言及されるトピックを抽出
    topics = []
    
    if context[:conversation_history]
      context[:conversation_history].each do |msg|
        content = msg[:content] || ''
        topics.concat(extract_keywords(content))
      end
    end
    
    # カテゴリごとにグループ化
    categorized = {}
    TOPIC_CATEGORIES.each do |category, words|
      matching = topics & words
      categorized[category.to_s] = matching unless matching.empty?
    end
    
    # 最も頻纁なカテゴリを返す
    return 'general' if categorized.empty?
    
    most_frequent = categorized.max_by { |_, keywords| keywords.size }&.first
    most_frequent || 'general'
  end
  
  # メッセージからトピックを抽出
  def extract_message_topic(message)
    keywords = extract_keywords(message)
    category = find_dominant_category(keywords)
    
    # categoryがSymbolの場合は文字列に変換
    result = category || keywords.first || 'unknown'
    result.is_a?(Symbol) ? result.to_s : result
  end
  
  # キーワードを抽出
  def extract_keywords(text)
    return [] unless text
    
    keywords = []
    
    # 類義語マッピング
    synonyms = {
      '料金' => ['料金', '価格', '費用', 'コスト'],
      'プラン' => ['プラン', '設定', 'プログラム'],
      '価格' => ['価格', '料金', '値段', '費用']
    }
    
    TOPIC_CATEGORIES.each do |_, words|
      words.each do |word|
        if text.include?(word)
          keywords << word
          # 類義語も追加
          synonyms[word]&.each { |syn| keywords << syn if text.include?(syn) }
        end
      end
    end
    
    # 追加の一般的なキーワード
    additional = ['価格', '設定', '値段', '費用']
    additional.each { |word| keywords << word if text.include?(word) && !keywords.include?(word) }
    
    keywords.uniq
  end
  
  # トピックのカテゴリを検索
  def find_topic_category(topic)
    # topicを文字列に変換
    topic_str = topic.to_s
    
    TOPIC_CATEGORIES.each do |category, words|
      return category if words.any? { |word| topic_str.include?(word) }
    end
    nil
  end
  
  # 支配的なカテゴリを検索
  def find_dominant_category(keywords)
    category_counts = {}
    
    keywords.each do |keyword|
      TOPIC_CATEGORIES.each do |category, words|
        if words.include?(keyword)
          category_counts[category] = (category_counts[category] || 0) + 1
        end
      end
    end
    
    # カテゴリをSymbolとして返す
    category_counts.max_by { |_, count| count }&.first
  end
  
  # カテゴリが関連しているか判定
  def related_categories?(cat1, cat2)
    related = {
      business: [:technical],
      technical: [:business],
      greeting: [:business, :technical]
    }
    
    related[cat1]&.include?(cat2) || related[cat2]&.include?(cat1)
  end
  
  # 逸脱タイプを判定
  def determine_deviation_type(message, topic)
    return 'personal_question' if personal_question?(message)
    return 'inappropriate_request' if inappropriate_request?(message)
    return 'different_domain' if different_domain?(topic)
    'off_topic'
  end
  
  # 個人的な質問か判定
  def personal_question?(message)
    TOPIC_CATEGORIES[:personal].any? { |word| message.include?(word) }
  end
  
  # 不適切なリクエストか判定
  def inappropriate_request?(message)
    inappropriate_words = %w[悪口 批判 違法 犯罪]
    inappropriate_words.any? { |word| message.include?(word) }
  end
  
  # 異なるドメインか判定
  def different_domain?(topic)
    unrelated_domains = %w[車 不動産 医療 法律]
    unrelated_domains.any? { |domain| topic.include?(domain) }
  end
  
  # 信頼度を計算
  def calculate_confidence(distance)
    return 1.0 if distance > 0.9
    return 0.9 if distance > 0.7
    return 0.5 if distance > 0.5
    0.3
  end
  
  # 深刻度を計算
  def calculate_severity(deviation_type)
    severity_map = {
      'inappropriate_request' => 'high',
      'different_domain' => 'high',
      'personal_question' => 'medium',
      'off_topic' => 'low'
    }
    
    severity_map[deviation_type] || 'low'
  end
  
  # 遷移フレーズか判定
  def is_transition_phrase?(message)
    transition_phrases = %w[ところで それから 別の質問 もう一つ ありがとう]
    transition_phrases.any? { |phrase| message.include?(phrase) }
  end
  
  # 継続タイプを判定
  def determine_continuation_type(message, context)
    return 'deep_dive' if message.include?('詳しく') || message.include?('詳細') || message.include?('設定') || message.include?('方法')
    return 'clarification' if message.include?('どういうこと') || message.include?('意味')
    return 'example_request' if message.include?('例') || message.include?('具体的')
    'follow_up'
  end
  
  # リダイレクト提案を生成
  def generate_redirect_suggestion(main_topic)
    "#{main_topic}についてのご質問にお答えします"
  end
  
  # リダイレクトメッセージを構築
  def build_redirect_message(main_topic)
    topic_phrases = {
      'pricing' => '料金プラン',
      'features' => '機能',
      'case_studies' => '導入事例',
      'technical' => '技術仕様',
      'business' => 'ビジネス要件'
    }
    
    topic_phrase = topic_phrases[main_topic] || main_topic
    "#{topic_phrase}についてご説明させていただきます"
  end
  
  # 遷移フレーズを選択
  def select_transition_phrase(deviation_type)
    phrases = {
      'personal_question' => '恐れ入りますが、',
      'off_topic' => '申し訳ございませんが、',
      'different_domain' => 'お問い合わせの件につきましては、',
      'inappropriate_request' => '申し訳ございませんが、'
    }
    
    phrases[deviation_type] || ''
  end
  
  # リダイレクトオプションを生成
  def generate_redirect_options(main_topic, deviation_type)
    options = []
    
    # 丁寧な軌道修正
    options << "#{main_topic}について引き続きご説明させていただけますでしょうか"
    
    # 直接的な軌道修正
    options << "#{main_topic}に関するご質問にお答えします"
    
    # 新しい話題への移行提案
    if deviation_type == 'off_topic'
      options << "別のトピックについてご質問がございましたら、改めてお伺いします"
    end
    
    options
  end
  
  # 意図を分析
  def analyze_intent(content)
    # 「検討しています」は優先度を上げる
    return 'purchase_inquiry' if content =~ /購入|検討して|導入/
    return 'information_seeking' if content =~ /教えて|知りたい|について/
    return 'support_request' if content =~ /困って|エラー|動かない/
    return 'comparison' if content =~ /比較|違い|どちら/
    'general_inquiry'
  end
  
  # トピックを分類
  def categorize_topics(topics)
    categorized = []
    
    TOPIC_CATEGORIES.each do |category, words|
      matching = topics & words
      categorized << category.to_s unless matching.empty?
    end
    
    categorized
  end
  
  # 会話ステージを判定
  def determine_conversation_stage(messages)
    return 'greeting' if messages.size <= 2
    
    last_messages = messages.last(3).map { |m| m[:content] }.join(' ')
    
    return 'closing' if last_messages =~ /ありがとう|契約|申し込み/
    return 'evaluation' if last_messages =~ /検討|比較|どちら/
    return 'negotiation' if last_messages =~ /価格|値引き|条件/
    
    'discovery'
  end
  
  # 目標の信頼度を計算
  def calculate_goal_confidence(intents, topics)
    return 0.3 if intents.empty? || topics.empty?
    
    # 意図の一貫性
    intent_consistency = intents.uniq.size == 1 ? 1.0 : 0.5
    
    # トピックの関連性
    topic_relevance = topics.size > 3 ? 0.8 : 0.5
    
    (intent_consistency + topic_relevance) / 2
  end
  
  # トーンを選択
  def select_tone(severity, deviation_type)
    return 'firm_but_polite' if severity == 'high'
    # personal_questionでもデフォルトはpolite_redirectとする
    'polite_redirect'
  end
  
  # 応答メッセージを構築
  def build_response_message(main_topic, deviation_type, tone)
    # main_topicを日本語に変換
    topic_phrase = translate_topic(main_topic)
    
    if deviation_type == 'inappropriate_request'
      "申し訳ございませんが、そのようなご要望にはお答えできません。#{topic_phrase}についてご案内させていただけますでしょうか。"
    elsif deviation_type == 'personal_question'
      "恐れ入りますが、個人的な質問にはお答えできません。#{topic_phrase}について何かご不明な点はございますか？"
    elsif deviation_type == 'different_domain'
      "申し訳ございませんが、その分野については専門外となります。#{topic_phrase}についてお手伝いできることはございますか？"
    else
      "#{topic_phrase}について引き続きご説明させていただきます。"
    end
  end
  
  # トピックを日本語に変換
  def translate_topic(topic)
    translations = {
      'product_features' => '製品機能',
      'pricing' => '料金プラン',
      'features' => '機能',
      'case_studies' => '導入事例',
      'technical' => '技術仕様',
      'business' => 'ビジネス要件',
      'general' => 'お問い合わせ内容'
    }
    
    translations[topic] || topic
  end
  
  # 承認すべきか判定
  def should_acknowledge?(deviation_type)
    %w[personal_question off_topic].include?(deviation_type)
  end
  
  # 代替案を提供すべきか判定
  def should_offer_alternative?(deviation_type)
    %w[inappropriate_request different_domain].include?(deviation_type)
  end
  
  # 推奨アクションを決定
  def recommend_action(deviation_rate, confusion)
    return 'provide_guidance' if confusion
    return 'gentle_reminder' if deviation_rate > 0.2
    return 'continue_normally' if deviation_rate < 0.1
    'monitor_closely'
  end
end