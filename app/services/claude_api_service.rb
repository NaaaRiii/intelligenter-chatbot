# frozen_string_literal: true

# Claude APIとの通信を管理するサービスクラス
class ClaudeApiService
  class ApiError < StandardError; end

  def initialize
    api_key = if Rails.env.test?
                'test_api_key'
              else
                Rails.application.credentials.dig(:anthropic, :api_key) || ENV.fetch('ANTHROPIC_API_KEY', nil)
              end

    @client = Anthropic::Client.new(access_token: api_key)
    @company_knowledge = CompanyKnowledgeService.new
  end

  # 会話から隠れたニーズを分析
  def analyze_conversation(conversation_history, user_query = nil)
    prompt = build_analysis_prompt(conversation_history, user_query)

    response = call_anthropic_messages(
      model: 'claude-3-haiku-20240307', # 高速・低コストなモデルを使用
      max_tokens: 1000,
      temperature: 0.3,
      system: enhanced_system_prompt,
      messages: [
        { role: 'user', content: prompt }
      ]
    )

    parse_analysis_response(response)
  rescue StandardError => e
    Rails.logger.error "Claude API Error: #{e.message}"
    raise ApiError, "分析処理中にエラーが発生しました: #{e.message}"
  end

  # チャットボットの応答を生成
  def generate_response(conversation_history, user_message)
    Rails.logger.info "[ClaudeAPI] generate_response called with:"
    Rails.logger.info "  - conversation_history: #{conversation_history.inspect}"
    Rails.logger.info "  - user_message: #{user_message}"
    
    messages = build_conversation_messages(conversation_history, user_message)
    Rails.logger.info "[ClaudeAPI] Built messages: #{messages.inspect}"

    response = call_anthropic_messages(
      model: 'claude-3-haiku-20240307',
      max_tokens: 500,
      temperature: 0.7,
      system: enhanced_chatbot_system_prompt,
      messages: messages
    )
    
    Rails.logger.info "[ClaudeAPI] Raw response: #{response.inspect}"
    
    result = extract_text_content(response)
    Rails.logger.info "[ClaudeAPI] Extracted text: #{result}"
    
    result
  rescue StandardError => e
    Rails.logger.error "[ClaudeAPI] Error: #{e.message}"
    Rails.logger.error "[ClaudeAPI] Backtrace: #{e.backtrace.first(3).join("\n")}"
    fallback_response
  end

  # カテゴリー別のシステムプロンプトを使用して応答を生成
  def generate_response_with_category(conversation_history, user_message, category)
    messages = build_conversation_messages(conversation_history, user_message)
    system_prompt = build_category_specific_prompt(category)

    response = call_anthropic_messages(
      model: 'claude-3-haiku-20240307',
      max_tokens: 800,
      temperature: 0.7,
      system: system_prompt,
      messages: messages
    )

    extract_text_content(response)
  rescue StandardError => e
    Rails.logger.error "Claude API Error with category #{category}: #{e.message}"
    fallback_response
  end

  # 拡張コンテキストを含めて応答を生成
  def generate_response_with_context(conversation_history, user_message, enriched_context)
    # コンテキストを含むシステムプロンプトを構築
    system_prompt_with_context = build_system_prompt_with_context(enhanced_chatbot_system_prompt, enriched_context)
    
    # コンテキストを含むメッセージを構築
    messages = build_messages_with_context(conversation_history, user_message, enriched_context)

    response = call_anthropic_messages(
      model: 'claude-3-haiku-20240307',
      max_tokens: 800, # コンテキストがあるため増量
      temperature: 0.7,
      system: system_prompt_with_context,
      messages: messages
    )

    extract_text_content(response)
  rescue StandardError => e
    Rails.logger.error "Claude API Error with context: #{e.message}"
    # コンテキストなしでフォールバック
    generate_response(conversation_history, user_message)
  end

  # FAQ検索用の質問埋め込みを生成（将来的な拡張用）
  def generate_embedding(text)
    # 注: Anthropic APIは直接埋め込みを提供していないため、
    # 実装時は別のサービス（OpenAI等）を使用するか、
    # テキスト類似度ベースの検索を実装
    raise NotImplementedError, 'Embedding generation is not yet implemented'
  end

  # publicメソッドとしてプロンプトを公開
  def system_prompt
    enhanced_system_prompt
  end

  def chatbot_system_prompt
    enhanced_chatbot_system_prompt
  end

  def build_analysis_prompt(conversation_history, user_query)
    enhanced_build_analysis_prompt(conversation_history, user_query)
  end

  # 応答テキストの簡易整形（重複行を除去、空行の連続を抑制）
  # LLMが同趣旨の文を繰り返すケースの可読性を改善する
  def compact_text(text)
    return '' if text.nil?

    require 'set'
    seen = Set.new
    output_lines = []
    previous_blank = false

    text.to_s.each_line do |line|
      raw = line.rstrip
      trimmed = raw.strip
      is_blank = trimmed.empty?

      # 連続する空行は1つに抑制
      if is_blank
        unless previous_blank
          output_lines << ''
        end
        previous_blank = true
        next
      end

      key = trimmed.gsub(/\s+/, ' ')
      unless seen.include?(key)
        output_lines << raw
        seen.add(key)
      end
      previous_blank = false
    end

    output_lines.join("\n").strip
  end

  private

  # カテゴリー別のシステムプロンプトを構築
  def build_category_specific_prompt(category)
    base_prompt = enhanced_chatbot_system_prompt
    category_specific_content = case category
    when 'tech' # 画面側の「技術・システム関連」と整合
      development_category_prompt
    when 'cost'
      cost_category_prompt
    when 'cdp'
      cdp_category_prompt
    when 'ma_crm'
      ma_crm_category_prompt
    when 'advertising'
      advertising_category_prompt
    when 'analytics'
      analytics_category_prompt
    when 'development'
      development_category_prompt
    when 'ecommerce'
      ecommerce_category_prompt
    when 'ai_ml'
      ai_ml_category_prompt
    when 'organization'
      organization_category_prompt
    when 'competition'
      competition_category_prompt
    else
      ""
    end
    
    "#{base_prompt}\n\n## カテゴリー専門知識\n#{category_specific_content}"
  end

  # 費用カテゴリーの専門プロンプト
  def cost_category_prompt
    <<~PROMPT
      ### 費用・契約に関する専門知識

      **予算別サービス提案**
      
      **〜50万円の予算で提供可能なサービス：**
      
      1. **Google Ads運用代行（月額15-25万円）**
         - 広告費別途（月20-30万円推奨）
         - キーワード調査、広告文作成、入札調整
         - 月次レポート、改善提案
         - 予想効果：CPA改善20-30%、CVR向上15-25%
      
      2. **MA/CRM初期設定サービス（30-45万円）**
         - HubSpot、Salesforce等の初期設定
         - リード管理フロー構築
         - 基本的な自動化シナリオ設計
         - 予想効果：営業効率30%向上、リード漏れ80%削減
      
      3. **SEOコンサルティング（月額20-35万円）**
         - キーワード戦略立案
         - テクニカルSEO改善
         - コンテンツ戦略設計
         - 予想効果：オーガニック流入40-60%増、検索順位平均10位向上
      
      4. **ECサイト改善（25-40万円）**
         - UI/UX改善提案
         - カート放棄率対策
         - 決済フロー最適化
         - 予想効果：CVR 20-35%改善、売上15-25%向上
      
      5. **データ分析ダッシュボード構築（20-35万円）**
         - Google Analytics 4設定
         - Looker Studio活用
         - KPI可視化、自動レポート
         - 予想効果：分析工数70%削減、意思決定スピード2倍

      **料金体系の特徴：**
      - 成果報酬オプション有り（基本料金+成果連動）
      - 月額サブスクリプション対応
      - 段階的導入で初期投資を抑制可能
      - ROI保証制度（3ヶ月で効果が出ない場合は返金）
      
      **次のステップ：**
      予算と課題に応じて、最適なプランを無料診断でご提案いたします。
    PROMPT
  end

  # CDP運用カテゴリーの専門プロンプト  
  def cdp_category_prompt
    <<~PROMPT
      ### CDP運用に関する専門知識

      **CDPサービス詳細：**
      
      1. **データ統合・管理**
         - 複数のタッチポイントからの顧客データ統合
         - リアルタイムデータ同期
         - データクレンジング・正規化
      
      2. **セグメント設計・運用**
         - 行動ベース・属性ベースセグメンテーション
         - 動的セグメント更新
         - A/Bテストによるセグメント最適化
      
      3. **外部ツール連携**
         - MA/CRM、広告プラットフォームとの連携
         - APIによるリアルタイムデータ同期
         - カスタマージャーニー可視化
      
      **提供可能なCDPソリューション：**
      - Salesforce Data Cloud
      - Adobe Real-time CDP  
      - Treasure Data CDP
      - カスタムCDP開発
      
      課題やご要望をお聞かせください。最適なCDP戦略をご提案いたします。
    PROMPT
  end

  # その他のカテゴリープロンプトも同様に定義...
  def ma_crm_category_prompt
    "MA/CRM最適化に関する専門知識とサービス詳細をここに記載"
  end

  def advertising_category_prompt  
    "Web広告運用に関する専門知識とサービス詳細をここに記載"
  end

  def analytics_category_prompt
    "データ分析に関する専門知識とサービス詳細をここに記載"
  end

  def development_category_prompt
    "システム開発に関する専門知識とサービス詳細をここに記載"
  end

  def ecommerce_category_prompt
    "ECサイト運営に関する専門知識とサービス詳細をここに記載"
  end

  def ai_ml_category_prompt
    "AI・機械学習に関する専門知識とサービス詳細をここに記載"
  end

  def organization_category_prompt
    "組織・体制に関する専門知識とサービス詳細をここに記載"
  end

  def competition_category_prompt
    "競合対策に関する専門知識とサービス詳細をここに記載"
  end

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

  def enhanced_chatbot_system_prompt
    <<~PROMPT
      あなたはBtoB SaaSのカスタマーサポートボットです。
      デジタルマーケティングに特化した専門知識を持ち、親切で専門的な対応を心がけます。
      DataPro Solutions株式会社の代表として、Google Ads、Meta広告、SEO、MA/CRMなど
      デジタルマーケティング全般に関する深い知識でサポートします。
      
      ## 会社のサービス
      #{@company_knowledge.format_for_prompt(category: 'services')}
      
      ## 専門分野
      - CDP（カスタマーデータプラットフォーム）
      - MA/CRM導入・改善支援
      - 広告運用（Google Ads、Meta広告、Yahoo!広告）
      - SEO・コンテンツマーケティング
      - ECサイト運営支援
      
      以下のガイドラインに従ってください：
      1. 簡潔で分かりやすい回答を心がける
      2. 技術的な内容も噛み砕いて説明する
      3. 必要に応じて具体例を提示する
      4. 解決できない場合は、人間のサポート担当者への引き継ぎを提案する
      5. 顧客の感情に配慮した返答をする
    PROMPT
  end

  def enhanced_build_analysis_prompt(conversation_history, user_query)
    <<~PROMPT
      以下の会話履歴を分析し、顧客の隠れたニーズと推奨アクションを特定してください。

      【会話履歴】
      #{format_conversation(conversation_history)}

      #{"【最新の質問】\n#{user_query}" if user_query.present?}

      この会話から、顧客が明示的に述べていない潜在的なニーズや課題を見つけ出し、
      プロアクティブな提案を生成してください。
    PROMPT
  end

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
    PROMPT
  end

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

  def original_system_prompt
    <<~PROMPT
      あなたはBtoB SaaSのカスタマーサクセスAIアシスタントです。
      顧客との会話を分析し、隠れたニーズや課題を発見して、プロアクティブな提案を行います。

      分析結果は必ず以下のJSON形式で出力してください：
      {
        "hidden_needs": [
          {
            "need_type": "効率化|自動化|コスト削減|機能改善|その他",
            "evidence": "会話からの具体的な証拠",
            "confidence": 0.0-1.0の数値,
            "proactive_suggestion": "具体的な提案内容"
          }
        ],
        "customer_sentiment": "positive|neutral|negative|frustrated",
        "priority_level": "low|medium|high",
        "escalation_required": true|false,
        "escalation_reason": "エスカレーションが必要な理由（必要な場合のみ）"
      }
    PROMPT
  end

  def original_chatbot_system_prompt
    <<~PROMPT
      あなたはBtoB SaaSのカスタマーサポートボットです。
      親切で専門的な対応を心がけ、顧客の問題解決を支援します。

      以下のガイドラインに従ってください：
      1. 簡潔で分かりやすい回答を心がける
      2. 技術的な内容も噛み砕いて説明する
      3. 必要に応じて具体例を提示する
      4. 解決できない場合は、人間のサポート担当者への引き継ぎを提案する
      5. 顧客の感情に配慮した返答をする
    PROMPT
  end

  def original_build_analysis_prompt(conversation_history, user_query)
    <<~PROMPT
      以下の会話履歴を分析し、顧客の隠れたニーズと推奨アクションを特定してください。

      【会話履歴】
      #{format_conversation(conversation_history)}

      #{"【最新の質問】\n#{user_query}" if user_query.present?}

      この会話から、顧客が明示的に述べていない潜在的なニーズや課題を見つけ出し、
      プロアクティブな提案を生成してください。
    PROMPT
  end

  def build_conversation_messages(conversation_history, user_message)
    messages = []

    # 会話履歴を追加（最新の10件まで）
    recent_history = conversation_history.last(10)
    recent_history.each do |msg|
      role = msg[:role] == 'user' ? 'user' : 'assistant'
      messages << { role: role, content: msg[:content] }
    end

    # 最新のユーザーメッセージを追加
    messages << { role: 'user', content: user_message }

    messages
  end

  def format_conversation(conversation_history)
    conversation_history.map do |msg|
      "#{msg[:role] == 'user' ? 'ユーザー' : 'サポート'}: #{msg[:content]}"
    end.join("\n")
  end

  def parse_analysis_response(response)
    content = extract_text_content(response)

    # JSONブロックを抽出（```json ... ``` または直接のJSON）
    json_match = content.match(/```json\s*(.*?)\s*```/m) || content.match(/\{.*\}/m)

    if json_match
      JSON.parse(json_match[1] || json_match[0])
    else
      # JSONが見つからない場合のフォールバック
      default_analysis_result
    end
  rescue JSON::ParserError => e
    Rails.logger.error "JSON Parse Error: #{e.message}"
    default_analysis_result
  end

  def extract_text_content(response)
    return '' if response.nil?

    content = if response.is_a?(Hash)
                response[:content] || response['content']

              elsif response.respond_to?(:content)
                response.content
              elsif response.respond_to?(:[]) && (response[:content] || response['content'])
                response[:content] || response['content']
              else
                nil
              end

    if content
      Array(content).map do |item|
        if item.is_a?(Hash)
          item_text = item[:text] || item['text']
          item_type = item[:type] || item['type']
          item_text if item_type == 'text' && item_text
        elsif item.respond_to?(:text) || item.respond_to?(:type)
          item_type = item.respond_to?(:type) ? item.type : (item[:type] || item['type'])
          item_text = item.respond_to?(:text) ? item.text : (item[:text] || item['text'])
          item_text if item_type.to_s == 'text' && item_text
        elsif item.is_a?(String)
          item
        end
      end.compact.join("\n")
    else
      response.to_s
    end
  end

  # Anthropic API呼び出しの互換レイヤー
  def call_anthropic_messages(params)
    # 1) 新しめのgem形態: client.messages.create(...)
    begin
      messages_client = @client.messages
      if messages_client.respond_to?(:create)
        return messages_client.create(params)
      end
    rescue NoMethodError
      # 下でHTTPフォールバック
    end

    # 2) 旧来/ラッパー形態: client.messages(...)
    begin
      maybe_response = @client.messages(**params)
      # 実際のレスポンス（Hash）かを判定
      if maybe_response.is_a?(Hash) && (maybe_response[:content] || maybe_response['content'])
        return maybe_response
      end
    rescue StandardError
      # 下でHTTPフォールバック
    end

    # 3) HTTPフォールバック（Faraday）
    http_messages_create(params)
  end

  def http_messages_create(params)
    api_key = Rails.application.credentials.dig(:anthropic, :api_key) || ENV['ANTHROPIC_API_KEY']
    raise ApiError, 'Anthropic APIキーが設定されていません' if api_key.blank?

    conn = Faraday.new(url: 'https://api.anthropic.com') do |f|
      f.request :json
      f.response :json, content_type: /json/
      f.adapter Faraday.default_adapter
    end

    response = conn.post('/v1/messages') do |req|
      req.headers['x-api-key'] = api_key
      req.headers['anthropic-version'] = '2023-06-01'
      req.headers['content-type'] = 'application/json'
      req.body = params
    end

    if response.status.to_i >= 200 && response.status.to_i < 300
      response.body
    else
      raise ApiError, "Anthropic API error: #{response.status} #{response.body}"
    end
  end

  def default_analysis_result
    {
      'hidden_needs' => [],
      'customer_sentiment' => 'neutral',
      'priority_level' => 'low',
      'escalation_required' => false
    }
  end

  def fallback_response
    'お問い合わせありがとうございます。申し訳ございませんが、現在システムに接続できません。' \
      'しばらくしてから再度お試しいただくか、サポートチームまでお問い合わせください。'
  end

  # コンテキストを含むシステムプロンプトを構築
  def build_system_prompt_with_context(base_prompt, enriched_context)
    context_section = format_enriched_context(enriched_context)
    
    <<~PROMPT
      #{base_prompt}
      
      ## 関連コンテキスト情報
      #{context_section}
      
      上記のコンテキスト情報を活用して、より的確で具体的な回答を提供してください。
    PROMPT
  end

  # コンテキストを含むメッセージを構築
  def build_messages_with_context(conversation_history, user_message, enriched_context)
    messages = build_conversation_messages(conversation_history, user_message)
    
    # RAGコンテキストがある場合は最初に追加
    if enriched_context[:rag_context]
      context_message = format_rag_context(enriched_context[:rag_context])
      messages.unshift({ role: 'assistant', content: context_message })
    end
    
    messages
  end

  # エンリッチされたコンテキストをフォーマット
  def format_enriched_context(enriched_context)
    sections = []
    
    if enriched_context[:faqs].present?
      faq_text = enriched_context[:faqs].map { |faq| 
        "Q: #{faq.content['question']}\nA: #{faq.content['answer']}" 
      }.join("\n\n")
      sections << "### 関連FAQ\n#{faq_text}"
    end
    
    if enriched_context[:case_studies].present?
      case_text = enriched_context[:case_studies].map { |cs| 
        "問題: #{cs.problem_type}\n解決: #{cs.solution}" 
      }.join("\n\n")
      sections << "### 類似事例\n#{case_text}"
    end
    
    if enriched_context[:product_info].present?
      product_text = enriched_context[:product_info].map { |pi| 
        pi.content['name'] 
      }.join(", ")
      sections << "### 関連製品\n#{product_text}"
    end
    
    sections.join("\n\n")
  end

  # RAGコンテキストをフォーマット
  def format_rag_context(rag_context)
    return '' unless rag_context
    
    sections = []
    
    if rag_context[:retrieved_messages].present?
      similar_messages = rag_context[:retrieved_messages].take(3).map { |msg|
        "- #{msg[:message].content} (関連度: #{(msg[:score] * 100).round}%)"
      }.join("\n")
      sections << "過去の類似ケース:\n#{similar_messages}"
    end
    
    if rag_context[:relevant_solutions].present?
      solutions = rag_context[:relevant_solutions].join("\n- ")
      sections << "推奨される解決策:\n- #{solutions}"
    end
    
    sections.join("\n\n")
  end
end
