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

    response = @client.messages(
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
    messages = build_conversation_messages(conversation_history, user_message)

    response = @client.messages(
      model: 'claude-3-haiku-20240307',
      max_tokens: 500,
      temperature: 0.7,
      system: enhanced_chatbot_system_prompt,
      messages: messages
    )

    extract_text_content(response)
  rescue StandardError => e
    Rails.logger.error "Claude API Error: #{e.message}"
    fallback_response
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

  private

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
    if response.is_a?(Hash) && response['content']
      Array(response['content']).map do |content_item|
        content_item['text'] if content_item['type'] == 'text'
      end.compact.join("\n")
    else
      response.to_s
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
end
