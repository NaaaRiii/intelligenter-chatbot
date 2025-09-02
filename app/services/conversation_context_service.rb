# frozen_string_literal: true

# 会話のコンテキスト（文脈）を管理するサービス
class ConversationContextService
  # コンテキスト構築の最大メッセージ数
  MAX_CONTEXT_MESSAGES = 20
  RECENT_MESSAGES_COUNT = 10
  
  # コンテキストを構築
  def build_context(conversation)
    messages = conversation.messages.order(:created_at).last(MAX_CONTEXT_MESSAGES)
    history = format_conversation_history(messages)
    
    {
      conversation_history: history,
      summary: generate_summary(history),
      key_points: extract_key_points(history),
      current_topic: determine_current_topic(history),
      recent_messages: history.last(RECENT_MESSAGES_COUNT)
    }
  end
  
  # エンティティ（固有名詞や重要情報）を抽出
  def extract_entities(messages)
    entities = {}
    messages = ensure_array(messages)
    
    messages.each do |msg|
      content = msg[:content] || msg['content'] || ''
      
      # 会社名
      if content =~ /(株式会社[^\s、。の]+)/
        entities[:company_name] = $1.strip
      elsif content =~ /([^\s、。の]+株式会社)/
        entities[:company_name] = $1.strip
      elsif content =~ /(有限会社[^\s、。の]+)/
        entities[:company_name] = $1.strip
      elsif content =~ /([^\s、。の]+(?:法人|組合|機構|協会))/
        entities[:company_name] = $1.strip
      elsif content =~ /([A-Z][a-z]+(?:\s+[A-Z][a-z]+)*)\s*(?:社|Corp|Inc|Ltd)/
        entities[:company_name] = $1.strip
      end
      
      # 人名（簡易的な抽出）
      if content =~ /([一-龥]{1,4})(?:です|と申します|といいます)/ && $1 !~ /万円|千円|億円/
        entities[:person_name] = $1
      end
      
      # 予算
      if content =~ /(月額|年額)?(\d+[\d,]*)\s*(?:万|千|億)?円/
        prefix = $1 || ''
        amount = $2.gsub(',', '')
        unit = content =~ /億/ ? '億円' : content =~ /千/ ? '千円' : '万円'
        entities[:budget] = "#{prefix}#{amount}#{unit}"
      end
      
      # サービス・製品
      services = []
      service_keywords = ['SEO対策', 'リスティング広告', 'SNS運用', 'MA導入', 'CRM', 'SFA']
      service_keywords.each do |keyword|
        services << keyword if content.include?(keyword)
      end
      entities[:service] = services unless services.empty?
      
      # メールアドレス
      if content =~ /([a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,})/
        entities[:email] = $1
      end
      
      # 電話番号
      if content =~ /(0\d{1,4}-?\d{1,4}-?\d{4})/
        entities[:phone] = $1
      end
    end
    
    entities
  end
  
  # 意図を判定
  def determine_intent(messages)
    messages = ensure_array(messages)
    last_message = messages.last || {}
    content = last_message[:content] || last_message['content'] || ''
    
    intents = []
    
    # 比較・検討
    if content =~ /他社|違い|比較|メリット|デメリット|特徴/
      intents << { type: 'comparison', confidence: 0.9 }
    end
    
    # 価格関連
    if content =~ /料金|価格|費用|いくら|予算|コスト|プラン/
      intents << { type: 'pricing_inquiry', confidence: 0.85 }
    end
    
    # デモ・資料請求
    if content =~ /デモ|体験|試|資料|カタログ|パンフレット/
      intents << { type: 'demo_request', confidence: 0.85 }
    end
    
    # 比較・検討
    if content =~ /他社|違い|比較|メリット|デメリット|特徴/
      intents << { type: 'comparison', confidence: 0.8 }
    end
    
    # 技術サポート
    if content =~ /エラー|不具合|動かない|できない|やり方|方法/
      intents << { type: 'technical_support', confidence: 0.85 }
    end
    
    # 契約・申込
    if content =~ /契約|申込|申し込み|導入|始めたい|使いたい/
      intents << { type: 'contract_inquiry', confidence: 0.9 }
    end
    
    if intents.empty?
      return { type: 'general_inquiry', confidence: 0.5 }
    end
    
    # 最も確信度の高いものをprimaryとする
    intents.sort_by! { |i| -i[:confidence] }
    
    if intents.length == 1
      intents.first
    else
      {
        primary: intents.first[:type],
        secondary: intents[1..-1].map { |i| i[:type] },
        type: intents.first[:type],
        confidence: intents.first[:confidence]
      }
    end
  end
  
  # 関連するコンテキストを取得
  def get_relevant_context(conversation)
    # user_idを使用して関連会話を取得
    return {} unless conversation.user_id
    
    # 同じユーザーの過去の会話を取得
    past_conversations = Conversation.where(user_id: conversation.user_id)
                                     .where.not(id: conversation.id)
                                     .order(created_at: :desc)
                                     .limit(5)
    
    past_info = past_conversations.map do |conv|
      {
        id: conv.id,
        created_at: conv.created_at,
        metadata: conv.metadata,
        category: conv.metadata&.dig('category'),
        resolved: conv.metadata&.dig('resolved'),
        solution: conv.metadata&.dig('solution')
      }
    end
    
    # 過去の解決策を収集
    previous_solutions = past_info
                        .map { |info| info[:solution] }
                        .compact
                        .uniq
    
    {
      past_conversations: past_info,
      previous_solutions: previous_solutions,
      customer_history: {
        total_conversations: past_conversations.count,
        last_contact: past_conversations.first&.created_at
      }
    }
  end
  
  # コンテキストを更新
  def update_context(current_context, new_message)
    updated = current_context.deep_dup
    
    # 会話履歴に追加
    updated[:conversation_history] ||= []
    updated[:conversation_history] << new_message
    
    # キーポイントを更新
    updated[:key_points] ||= {}
    
    content = new_message[:content] || new_message['content']
    
    # 予算情報の更新
    if content =~ /(\d+[\d,]*)\s*(?:万|千|億)?円/
      amount = $1.gsub(',', '')
      unit = content =~ /億/ ? '億円' : content =~ /千/ ? '千円' : '万円'
      updated[:key_points]['budget'] = "#{amount}#{unit}"
    end
    
    # トピックの変化を検出
    old_topic = current_context[:current_topic]
    new_topic = detect_topic_from_message(content)
    
    if new_topic && new_topic != old_topic
      updated[:current_topic] = new_topic
      updated[:topic_changed] = true
    else
      updated[:topic_changed] = false
    end
    
    updated
  end
  
  # 会話履歴から要約を生成
  def generate_summary(messages)
    return '' if messages.empty?
    
    messages = ensure_array(messages)
    
    # 重要なポイントを抽出
    key_points = []
    
    messages.each do |msg|
      content = msg[:content] || msg['content'] || ''
      role = msg[:role] || msg['role']
      
      # ユーザーとアシスタント両方のメッセージを確認
      
      # 重要なキーワードを含む文を抽出
      if content =~ /(ECサイト|マーケティング|CVR|リピート|売上|課題|問題|改善)/
        key_points << content.gsub(/\s+/, ' ').strip[0..100]
      end
    end
    
    # 要約を生成
    if key_points.any?
      summary = key_points.first(3).join('。')
      summary += "。MA導入を検討中。" if messages.any? { |m| (m[:content] || m['content'] || '').include?('MA') }
      summary[0..199] # 200文字以内に制限
    else
      '顧客からの問い合わせ対応中'
    end
  end
  
  # コンテキストの関連性スコアを計算
  def calculate_context_relevance(context1, context2)
    return 0.0 unless context1 && context2
    
    key_points1 = context1[:key_points] || {}
    key_points2 = context2[:key_points] || {}
    
    score = 0.0
    weight_total = 0.0
    
    # カテゴリの一致
    if key_points1['category'] && key_points2['category']
      weight = 0.4
      score += weight if key_points1['category'] == key_points2['category']
      weight_total += weight
    end
    
    # 予算帯の近さ
    if key_points1['budget'] && key_points2['budget']
      weight = 0.3
      budget1 = extract_budget_amount(key_points1['budget'])
      budget2 = extract_budget_amount(key_points2['budget'])
      
      if budget1 && budget2
        diff_ratio = (budget1 - budget2).abs.to_f / [budget1, budget2].max
        score += weight * (1.0 - diff_ratio)
      end
      weight_total += weight
    end
    
    # 事業タイプの一致
    if key_points1['business_type'] && key_points2['business_type']
      weight = 0.3
      score += weight if key_points1['business_type'] == key_points2['business_type']
      weight_total += weight
    end
    
    weight_total > 0 ? score / weight_total : 0.0
  end
  
  private
  
  # 会話履歴をフォーマット
  def format_conversation_history(messages)
    messages.map do |msg|
      {
        role: msg.role,
        content: msg.content,
        created_at: msg.created_at,
        metadata: msg.metadata
      }
    end
  end
  
  # キーポイントを抽出
  def extract_key_points(history)
    key_points = {}
    
    history.each do |msg|
      content = msg[:content] || ''
      
      # カテゴリ判定
      if content =~ /マーケティング|広告|SEO|集客/
        key_points['category'] = 'marketing'
      elsif content =~ /技術|エラー|不具合|システム/
        key_points['category'] = 'tech'
      end
      
      # 事業タイプ
      if content =~ /(EC事業|小売|製造|サービス|BtoB|SaaS)/
        key_points['business_type'] = $1
      end
      
      # トピック
      if content =~ /ツール|選定|導入|検討/
        key_points['topic'] = 'ツール選定'
      elsif content =~ /課題|問題|改善/
        key_points['topic'] = '課題解決'
      end
    end
    
    key_points
  end
  
  # 現在のトピックを特定
  def determine_current_topic(history)
    return nil if history.empty?
    
    # 最後の数メッセージから判定
    recent = history.last(4)
    
    recent.reverse_each do |msg|
      content = msg[:content] || ''
      
      return '予算確認' if content =~ /予算|費用|料金|いくら/
      return '技術サポート' if content =~ /技術|サポート|エラー|不具合/
      return '導入検討' if content =~ /導入|契約|申込/
      return '機能説明' if content =~ /機能|できること|特徴/
      return 'ツール選定' if content =~ /ツール|選定|探して/
    end
    
    '一般問い合わせ'
  end
  
  # メッセージからトピックを検出
  def detect_topic_from_message(content)
    return nil unless content
    
    return '技術サポート' if content =~ /技術|サポート|エラー|不具合/
    return '予算確認' if content =~ /予算|費用|料金|いくら/
    return '導入検討' if content =~ /導入|契約|申込/
    return '機能説明' if content =~ /機能|できること|特徴/
    
    nil
  end
  
  # 配列を確実に返す
  def ensure_array(messages)
    return [] unless messages
    messages.is_a?(Array) ? messages : [messages]
  end
  
  # 予算額を数値として抽出
  def extract_budget_amount(budget_str)
    return nil unless budget_str
    
    if budget_str =~ /(\d+[\d,]*)/
      amount = $1.gsub(',', '').to_i
      amount *= 10000 if budget_str.include?('万')
      amount *= 1000 if budget_str.include?('千')
      amount *= 100000000 if budget_str.include?('億')
      amount
    end
  end
end