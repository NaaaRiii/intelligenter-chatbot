# frozen_string_literal: true

# 文脈を考慮した応答を生成するサービス
class ContextAwareResponseService
  # 指示語パターン
  REFERENCE_PATTERNS = /それ|これ|あれ|その|この|あの|そちら|こちら|あちら/
  
  # 会話ステージの定義
  CONVERSATION_STAGES = {
    greeting: '挨拶',
    requirement_gathering: '要件収集',
    solution_proposal: '提案',
    detail_explanation: '詳細説明',
    negotiation: '交渉',
    closing: 'クロージング'
  }.freeze
  
  def initialize
    @context_service = ConversationContextService.new
  end
  
  # 文脈を考慮した応答を生成
  def generate_response(message:, context:, conversation:)
    # 指示語の解決
    references = extract_references(message)
    resolved_references = {}
    
    references.each do |ref|
      next if ref == :count
      resolved_references[ref] = resolve_ambiguity(ref, context)
    end
    
    # 話題の継続性チェック
    previous_topic = context[:current_topic]
    new_topic = detect_topic(message)
    
    # 機能に関する質問は前のトピックの継続と見なす
    if message =~ /機能|どんな|何ができる/ && previous_topic
      topic_changed = false
    else
      topic_changed = new_topic && new_topic != previous_topic
    end
    
    # 前の会話内容を参照
    refers_to_previous = (!references.empty? || message =~ /詳しく|もっと|さらに|続き/) ? true : false
    
    # 文脈情報を抽出
    context_used = extract_context_info(context)
    
    # 人名をコンテキストから抽出（早期に処理）
    person_name = nil
    if context_used['person_name']
      person_name = context_used['person_name']
    else
      # ConversationContextServiceを使用してエンティティ抽出
      entities = @context_service.extract_entities(context[:conversation_history] || [])
      person_name = entities[:person_name] if entities[:person_name]
    end
    
    # 応答内容の生成
    content = build_response_content(
      message: message,
      context: context,
      resolved_references: resolved_references,
      topic_changed: topic_changed,
      refers_to_previous: refers_to_previous
    )
    
    # パーソナライズ
    personalized = false
    if person_name && !content.include?("#{person_name}様")
      content = "#{person_name}様、#{content}"
      personalized = true
    end
    
    {
      content: content,
      refers_to_previous: refers_to_previous,
      context_used: context_used,
      interpreted_reference: resolved_references.values.first,
      topic_continuation: !topic_changed,
      topic_changed: topic_changed,
      new_topic: topic_changed ? new_topic : nil,
      features_mentioned: extract_features(content),
      personalized: personalized,
      recommendation_based_on: determine_recommendation_basis(context),
      constraints_considered: extract_constraints(context),
      contradiction_detected: detect_contradiction(message, context),
      clarification_needed: needs_clarification?(message, context)
    }
  end
  
  # 会話フローを分析
  def analyze_conversation_flow(messages)
    return {} if messages.empty?
    
    # メイントピックの抽出
    main_topic = detect_main_topic(messages)
    
    # サブトピックの収集
    subtopics = []
    messages.each do |msg|
      content = msg[:content] || msg['content'] || ''
      subtopics << 'SEO' if content =~ /SEO/
      subtopics << 'SNS' if content =~ /SNS|ソーシャル/
      subtopics << 'MA' if content =~ /MA|マーケティングオートメーション/
      subtopics << 'CRM' if content =~ /CRM|顧客管理/
    end
    
    # 会話ステージの判定
    stage = determine_conversation_stage(messages)
    
    {
      main_topic: main_topic,
      subtopics: subtopics.uniq,
      conversation_stage: stage
    }
  end
  
  # 文脈を考慮したプロンプトを構築
  def build_contextual_prompt(message, context)
    prompt = []
    
    # ビジネス情報
    if context[:key_points]
      if context[:key_points]['business_type']
        prompt << "顧客業種: #{context[:key_points]['business_type']}"
      end
      if context[:key_points]['budget']
        prompt << "予算: #{context[:key_points]['budget']}"
      end
      if context[:key_points]['challenges']
        prompt << "課題: #{context[:key_points]['challenges']}"
      end
    end
    
    # 現在のトピック
    if context[:current_topic]
      prompt << "現在の話題: #{context[:current_topic]}"
    end
    
    # ユーザーメッセージ
    prompt << "質問: #{message}"
    
    prompt.join("\n")
  end
  
  # 指示語や代名詞を抽出
  def extract_references(message)
    references = []
    
    message.scan(REFERENCE_PATTERNS) do |match|
      references << match
    end
    
    references.uniq
  end
  
  # 曖昧な表現を文脈から解決
  def resolve_ambiguity(ambiguous_term, context)
    return nil unless context[:recent_messages]
    
    # 直近のアシスタントメッセージから候補を探す
    context[:recent_messages].reverse_each do |msg|
      next unless msg[:role] == 'assistant'
      
      content = msg[:content] || ''
      
      # プラン名を探す
      if content =~ /(スタンダードプラン|プレミアムプラン|エンタープライズプラン|ベーシックプラン)/
        return $1
      end
      
      # ツール名を探す
      if content =~ /(MAツール|CRMツール|分析ツール|統合型ツール)/
        return $1
      end
      
      # 機能名を探す
      if content =~ /(分析機能|レポート機能|自動化機能)/
        return $1
      end
    end
    
    nil
  end
  
  private
  
  # トピックを検出
  def detect_topic(message)
    return 'pricing' if message =~ /料金|価格|費用|プラン/
    return 'features' if message =~ /機能|できること|特徴/
    return 'demo' if message =~ /デモ|体験|試/
    return 'support' if message =~ /サポート|支援|ヘルプ/
    return 'timeline' if message =~ /期間|いつ|スケジュール/
    nil
  end
  
  # 文脈情報を抽出
  def extract_context_info(context)
    info = {}
    
    # key_pointsから情報を抽出
    if context[:key_points]
      info['budget'] = context[:key_points]['budget'] if context[:key_points]['budget']
      info['business_type'] = context[:key_points]['business_type'] if context[:key_points]['business_type']
      info['challenges'] = context[:key_points]['challenges'] if context[:key_points]['challenges']
    end
    
    # conversation_historyから予算情報も抽出
    if context[:conversation_history]
      context[:conversation_history].each do |msg|
        content = msg[:content] || ''
        if content =~ /(月額|年額)?(\d+[\d,]*)\s*(?:万|千|億)?円/
          prefix = $1 || '月額'
          amount = $2.gsub(',', '')
          unit = content =~ /億/ ? '億円' : content =~ /千/ ? '千円' : '万円'
          info['budget'] = "#{prefix}#{amount}#{unit}"
          break
        end
      end
    end
    
    info
  end
  
  # 応答内容を構築
  def build_response_content(message:, context:, resolved_references:, topic_changed:, refers_to_previous: false)
    content = []
    
    # 解決された参照がある場合
    if resolved_references.any?
      ref_content = resolved_references.values.first
      content << "#{ref_content}について"
    end
    
    # メッセージの内容に応じた応答
    if message =~ /いつから|いつ/
      content << "すぐにご利用開始いただけます"
    elsif message =~ /詳しく|もっと/
      if refers_to_previous && context[:recent_messages]
        # スタンダードプランへの参照を優先
        if context[:recent_messages].any? { |m| m[:content] && m[:content].include?('スタンダードプラン') }
          content << "スタンダードプランの詳細についてご説明します"
        else
          last_topic = nil
          context[:recent_messages].reverse_each do |msg|
            next unless msg[:role] == 'assistant'
            last_topic = extract_last_topic(msg)
            break if last_topic
          end
          content << "#{last_topic}の詳細についてご説明します" if last_topic
        end
      end
    elsif message =~ /デモ/
      content << "デモのご案内をさせていただきます"
    elsif message =~ /おすすめ|提案/
      constraints = extract_constraints(context)
      if constraints['budget'] =~ /100万/
        content << "エンタープライズプランがおすすめです"
      elsif constraints['budget'] =~ /50万/
        content << "スタンダードプランがおすすめです"
      else
        content << "お客様のご要望に最適なプランをご提案します"
      end
    elsif message =~ /機能/
      # 文脈からCVR関連の話題があるか確認
      if context[:conversation_history] && context[:conversation_history].any? { |m| m[:content] && m[:content].include?('CVR') }
        content << "MAツールの主要機能についてご説明します"
        content << "CVR改善のための分析機能"
        content << "リピート率向上のための自動化機能"
      else
        content << "機能についてご説明します"
      end
    elsif topic_changed && detect_topic(message) == 'pricing'
      content << "料金プランについてご説明します"
    elsif message =~ /フルサポート/
      # 矛盾検出用
      constraints = extract_constraints(context)
      if constraints['budget'] && constraints['budget'] =~ /10万/
        content << "ご予算とフルサポートのご要望について確認させてください"
      else
        content << "フルサポート付きプランをご案内します"
      end
    elsif message =~ /提案|おすすめ/ && message =~ /プラン/ && message !~ /フルサポート/
      # BtoB情報を考慮
      if context[:conversation_history] && context[:conversation_history].any? { |m| m[:content] && (m[:content].include?('BtoB') || m[:content].include?('SaaS')) }
        content << "BtoB SaaS企業様向けの最適プランをご提案します"
      else
        content << "お客様のご要望に最適なプランをご提案します"
      end
    elsif message =~ /最適なプランを提案/
      # BtoB情報を考慮して提案
      if context[:conversation_history] && context[:conversation_history].any? { |m| m[:content] && (m[:content].include?('BtoB') || m[:content].include?('SaaS')) }
        content << "BtoB SaaS企業様向けの最適プランをご提案します"
      else
        content << "お客様のご要望に最適なプランをご提案します"
      end
    end
    
    # デフォルト応答
    content << "承知いたしました" if content.empty?
    
    content.join("。")
  end
  
  # 機能を抽出
  def extract_features(content)
    features = []
    features << '分析機能' if content =~ /分析/
    features << '自動化機能' if content =~ /自動化/
    features << 'レポート機能' if content =~ /レポート/
    features
  end
  
  # 推奨根拠を判定
  def determine_recommendation_basis(context)
    basis = []
    
    if context[:key_points]
      basis << 'business_type' if context[:key_points]['business_type']
      basis << 'budget' if context[:key_points]['budget']
      basis << 'challenges' if context[:key_points]['challenges']
    end
    
    basis
  end
  
  # 制約条件を抽出
  def extract_constraints(context)
    constraints = {}
    
    if context[:conversation_history]
      context[:conversation_history].each do |msg|
        content = msg[:content] || ''
        
        if content =~ /(\d+ヶ月|[0-9０-９]+ヶ月)以内/
          constraints['timeline'] = $&
        end
        
        if content =~ /(月額)?(\d+[\d,]*)\s*(?:万|千|億)?円/
          amount = $2.gsub(',', '')
          unit = content =~ /億/ ? '億円' : content =~ /千/ ? '千円' : '万円'
          prefix = $1 || '月額'
          constraints['budget'] = "#{prefix}#{amount}#{unit}"
        end
      end
    end
    
    constraints
  end
  
  # 矛盾を検出
  def detect_contradiction(message, context)
    constraints = extract_constraints(context)
    
    # 低予算でフルサポートを要求
    if constraints['budget'] =~ /10万/ && message =~ /フルサポート/
      return true
    end
    
    # 短期間で大規模導入を要求
    if constraints['timeline'] =~ /1ヶ月/ && message =~ /全社導入|大規模/
      return true
    end
    
    false
  end
  
  # 確認が必要か判定
  def needs_clarification?(message, context)
    detect_contradiction(message, context) || 
    message =~ /本当に|確実に|絶対に/
  end
  
  # メイントピックを検出
  def detect_main_topic(messages)
    topics = Hash.new(0)
    
    messages.each do |msg|
      content = msg[:content] || msg['content'] || ''
      topics['tool_selection'] += 1 if content =~ /ツール|選定|探して/
      topics['pricing'] += 1 if content =~ /料金|価格|費用/
      topics['features'] += 1 if content =~ /機能|できること/
      topics['support'] += 1 if content =~ /サポート|支援/
    end
    
    topics.max_by { |_, count| count }&.first || 'general'
  end
  
  # 会話ステージを判定
  def determine_conversation_stage(messages)
    return 'greeting' if messages.size <= 2
    
    last_messages = messages.last(3)
    
    # 最後のメッセージから優先的に判定
    last_messages.reverse_each do |msg|
      content = msg[:content] || msg['content'] || ''
      
      return 'closing' if content =~ /契約|申込|導入決定/
      return 'negotiation' if content =~ /値引き|割引|特典/
      return 'detail_explanation' if content =~ /詳しく|詳細|具体的/
      # おすすめを含むがツール選定の文脈ではsolution_proposalとしない
      return 'solution_proposal' if content =~ /提案|最適/ && content !~ /ツール|探して/
    end
    
    # デフォルトはrequirement_gathering
    'requirement_gathering'
  end
  
  # 最後のトピックを抽出
  def extract_last_topic(message)
    content = message[:content] || ''
    
    return 'スタンダードプラン' if content =~ /スタンダードプラン/
    return 'プレミアムプラン' if content =~ /プレミアムプラン/
    return 'エンタープライズプラン' if content =~ /エンタープライズプラン/
    return 'MAツール' if content =~ /MAツール/
    return 'CVR改善' if content =~ /CVR改善/
    
    nil
  end
  
end