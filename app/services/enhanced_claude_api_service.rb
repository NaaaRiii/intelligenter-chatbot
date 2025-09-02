# frozen_string_literal: true

# 拡張版Claude APIサービス（専門性重視型プロンプトと会社情報を統合）
class EnhancedClaudeApiService < ClaudeApiService
  def initialize
    super
    @company_knowledge = CompanyKnowledgeService.new
    @inquiry_analyzer = InquiryAnalyzerService.new
  end

  # 拡張された応答生成
  def generate_enhanced_response(conversation_history, user_message, analysis = nil)
    # 自然な会話サービスを優先的に使用
    natural_service = NaturalConversationService.new
    context = {
      category: analysis&.dig(:category) || extract_category_from_history(conversation_history)
    }
    
    begin
      # AI APIを使用した自然な応答生成
      return natural_service.generate_natural_response(user_message, conversation_history, context)
    rescue StandardError => e
      Rails.logger.warn "Natural conversation service failed, falling back: #{e.message}"
      # フォールバック処理
    end
    
    analysis ||= @inquiry_analyzer.analyze(user_message, conversation_history)
    
    # 情報収集が必要な場合
    if should_collect_info?(conversation_history, analysis)
      return generate_info_collection_response(analysis[:category], analysis)
    end
    
    # 専門外でも、まずは可能な範囲で回答。その後で丁寧に誘導
    # 完全に不適切・危険な領域のみ断る（法律・医療・投資の明確な助言要求など）
    if hard_out_of_scope?(user_message)
      return handle_out_of_scope(analysis[:category])
    end
    
    # 通常の応答生成
    messages = build_contextualized_messages(conversation_history, user_message, analysis)
    
    response = call_anthropic_messages(
      model: 'claude-3-haiku-20240307',
      max_tokens: 1000,
      temperature: 0.7,
      system: enhanced_system_prompt,
      messages: messages
    )
    
    response_text = extract_text_content(response)
    response_text = compact_text(response_text)

    # 大きく話が逸れている場合は、元のカテゴリへ穏やかにリダイレクト
    begin
      deviation = TopicDeviationService.new.detect_deviation(message: user_message, conversation: OpenStruct.new(messages: conversation_history))
      if deviation[:deviated] && deviation[:topic_relevance].to_f < TopicDeviationService::TOPIC_RELEVANCE_THRESHOLD
        suggestion = TopicDeviationService.new.suggest_redirect(deviation)
        response_text = [response_text, "\n\n#{suggestion[:transition_phrase]}#{suggestion[:redirect_message]}。"].join
      end
    rescue StandardError => e
      Rails.logger.warn "Enhanced deviation handling skipped: #{e.message}"
    end

    add_follow_up_question(response_text, analysis[:category])
  rescue StandardError => e
    Rails.logger.error "Enhanced Claude API Error: #{e.message}"
    fallback_response
  end

  # 拡張されたシステムプロンプト
  def enhanced_system_prompt
    <<~PROMPT
      #{specialized_ai_prompt}
      
      ## 会社情報
      #{@company_knowledge.format_for_prompt}
      
      ## 基本ガイドライン
      #{base_guidelines}
      
      ## 会話管理
      - 3往復以内で必要な情報を収集する
      - 収集した情報は構造化してmetadataに保存する
      - 緊急度が高い場合は即座にエスカレーション
    PROMPT
  end

  # コンテキスト化されたメッセージ構築
  def build_contextualized_messages(conversation_history, user_message, analysis)
    messages = []
    
    # 会話履歴を追加
    conversation_history.last(5).each do |msg|
      role = msg[:role] == 'user' ? 'user' : 'assistant'
      messages << { role: role, content: msg[:content] }
    end
    
    # 現在のメッセージに分析結果を付加
    contextualized_message = <<~MESSAGE
      【ユーザーメッセージ】
      #{user_message}
      
      【分析結果】
      カテゴリ: #{analysis[:category]}
      意図: #{analysis[:intent]}
      緊急度: #{analysis[:urgency]}
      キーワード: #{analysis[:keywords].join(', ')}
      
      【関連情報】
      #{@company_knowledge.get_relevant_info(user_message).to_json}
    MESSAGE
    
    messages << { role: 'user', content: contextualized_message }
    messages
  end

  # 情報収集が必要かどうか判定
  def should_collect_info?(conversation_history, metadata)
    return true if conversation_history.empty?
    
    # metadataがハッシュでない場合の対処
    metadata = metadata.is_a?(Hash) ? metadata : {}
    
    category = metadata['category'] || metadata[:category] || 'general'
    required_info = determine_required_info(category)
    collected_info = extract_collected_info(metadata)
    
    # 必要な情報の半分以上が収集されていればfalse
    missing_info = required_info - collected_info
    missing_info.size > (required_info.size / 2)
  end

  # 情報収集用の質問を生成
  def generate_info_collection_questions(category, metadata)
    questions = []
    
    case category
    when 'marketing'
      questions << '現在実施中のマーケティング施策を教えてください' unless metadata.dig('customer_profile', 'current_marketing')
      questions << '月間のマーケティング予算はどの程度でしょうか？' unless metadata.dig('customer_profile', 'budget_range')
      questions << '主要なKPIは何ですか？' unless metadata.dig('customer_profile', 'kpis')
    when 'tech'
      questions << '現在の技術スタックを教えてください' unless metadata.dig('customer_profile', 'tech_stack')
      questions << '開発チームの規模はどの程度ですか？' unless metadata.dig('customer_profile', 'team_size')
      questions << 'システムの課題は何ですか？' unless metadata.dig('customer_profile', 'challenges')
    else
      questions << '貴社の業界を教えてください' unless metadata.dig('customer_profile', 'industry')
      questions << '解決したい課題は何ですか？' unless metadata.dig('customer_profile', 'main_challenges')
    end
    
    questions
  end

  # 専門外の質問への対応
  def handle_out_of_scope(category)
    <<~RESPONSE
      申し訳ございませんが、#{category}は私の専門領域外のため、
      詳細で確実な回答は控えさせていただきます。
      
      デジタルマーケティングの観点から関連してお答えできる部分があれば
      お話しできますが、#{category}の専門家にご相談されることをお勧めします。
      
      代わりに、マーケティング戦略の改善やデータ分析についてはいかがでしょうか？
    RESPONSE
  end

  # 危険/不適切な領域を弾く（法律・医療・投資の具体助言など）
  def hard_out_of_scope?(user_message)
    return false unless user_message
    patterns = [
      /法的.?助言|違法|犯罪|訴訟/, # 法律
      /医療|薬事|診断|処方/,       # 医療
      /投資|株|暗号資産|仮想通貨|為替/ # 金融
    ]
    patterns.any? { |re| user_message.match?(re) }
  end

  # フォローアップ質問を追加
  def add_follow_up_question(response, category)
    follow_ups = {
      'marketing' => [
        '他にもマーケティング施策についてご質問はありませんか？',
        '次は具体的な実施計画について掘り下げてみましょうか？',
        'ROI改善の具体策についてもご提案できます。'
      ],
      'tech' => [
        'システム構成についてさらに詳しくご説明しましょうか？',
        '技術的な実装方法について具体的にお話しできます。',
        'パフォーマンス改善策もご提案可能です。'
      ]
    }
    
    selected_follow_up = follow_ups[category]&.sample || '他にご質問はございませんか？'
    
    <<~ENHANCED_RESPONSE
      #{response}
      
      #{selected_follow_up}
    ENHANCED_RESPONSE
  end

  # カテゴリに応じた会社情報をフォーマット
  def format_with_company_knowledge(category)
    @company_knowledge.format_for_prompt(category: category)
  end

  private

  # 専門性重視型プロンプト
  def specialized_ai_prompt
    <<~PROMPT
      ## 基本設定
      あなたは**デジタルマーケティング**に特化した専門AIアシスタントです。
      DataPro Solutions株式会社の代表として、この領域での深い知識と実践的な経験を活かして、ユーザーをサポートしてください。
      
      ## 専門領域の定義
      **得意分野（積極的に回答）：**
      - デジタル広告運用（Google Ads、Meta広告、Yahoo!広告等）
      - SEO・コンテンツマーケティング
      - ソーシャルメディアマーケティング
      - メールマーケティング・MA（マーケティングオートメーション）
      - アクセス解析・効果測定（GA4、Search Console等）
      - ECサイト運営・CRO（コンバージョン率最適化）
      - インフルエンサーマーケティング
      - ブランディング・クリエイティブ戦略
      
      **専門外領域（慎重な対応）：**
      - 法律・税務関連の詳細な解釈や判断
      - 医療・薬事に関する専門的なアドバイス
      - 投資・金融商品の具体的な推奨
      
      ## 会話継続のための情報蓄積ルール
      
      ### 情報収集フェーズ
      初回の相談時は、以下の情報を収集してから回答してください：
      
      1. **事業概要**
         - 業界・事業規模
         - 主要なターゲット層
         - 現在の主力商品・サービス
      
      2. **マーケティング現状**
         - 実施中の施策
         - 予算規模感
         - 課題認識
      
      3. **目標・KPI**
         - 達成したい目標
         - 重要視している指標
         - 期限・優先度
      
      ## 回答スタイル
      
      ### やるべきこと ✅
      - **具体的で実践的な提案**を行う
      - 専門用語を使う場合は**必ず解説**を付ける
      - 複数の選択肢を提示し、**それぞれのメリット・デメリット**を説明
      - **次のステップ**を明確に示す
      - 不明な点があれば**積極的に質問**する
      
      ### 避けるべきこと ❌
      - 専門外の分野での断定的な回答
      - 一般論や教科書的な回答のみ
      - 情報不足のまま曖昧な提案をする
      - ユーザーの状況を無視した突飛な提案
    PROMPT
  end

  # 基本ガイドライン
  def base_guidelines
    <<~GUIDELINES
      ## コミュニケーションガイドライン
      1. 簡潔で分かりやすい回答を心がける
      2. 技術的な内容も噛み砕いて説明する
      3. 必要に応じて具体例を提示する
      4. 解決できない場合は、人間のサポート担当者への引き継ぎを提案する
      5. 顧客の感情に配慮した返答をする
    GUIDELINES
  end

  # 必要な情報を判定
  def determine_required_info(category)
    case category
    when 'marketing'
      %w[industry budget_range current_marketing kpis timeline]
    when 'tech'
      %w[tech_stack team_size challenges timeline budget_range]
    else
      %w[industry main_challenges budget_range timeline]
    end
  end

  # 収集済み情報を抽出
  def extract_collected_info(metadata)
    profile = metadata['customer_profile'] || metadata[:customer_profile] || {}
    profile.keys.map(&:to_s)
  end

  # 専門外かどうか判定
  def out_of_scope?(category)
    out_of_scope_categories = %w[legal medical finance hr]
    out_of_scope_categories.include?(category.to_s)
  end

  # 情報収集用の応答を生成
  def generate_info_collection_response(category, metadata)
    questions = generate_info_collection_questions(category, metadata)
    
    if questions.empty?
      return "必要な情報は揃いました。それでは、具体的なご提案をさせていただきます。"
    end
    
    <<~RESPONSE
      お問い合わせありがとうございます。
      最適なご提案をさせていただくため、いくつか確認させてください。
      
      #{questions.map.with_index(1) { |q, i| "#{i}. #{q}" }.join("\n")}
      
      これらの情報をお聞かせいただければ、より具体的で実践的なアドバイスが可能です。
    RESPONSE
  end

  # 会話履歴からカテゴリを抽出
  def extract_category_from_history(conversation_history)
    return 'general' if conversation_history.empty?
    
    # 最初のメッセージや最近のメッセージからカテゴリを推測
    recent_messages = conversation_history.last(3).map { |msg| msg[:content] }.join(' ')
    
    case recent_messages
    when /マーケティング|広告|SEO/
      'marketing'
    when /技術|システム|開発|API/
      'tech'
    when /EC|ショッピング|モール/
      'ecommerce'
    when /セキュリティ|保護|暗号/
      'security'
    else
      'general'
    end
  end
end