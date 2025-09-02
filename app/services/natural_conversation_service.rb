# frozen_string_literal: true

# 自然な会話を実現するためのサービス
class NaturalConversationService
  def initialize
    @claude_service = ClaudeApiService.new
    @openai_service = OpenaiChatService.new
  end

  # メッセージを分析して複数の質問を検出
  def analyze_message(message)
    # APIキーが設定されていない場合は即座にフォールバック
    if Rails.env.production? && !api_keys_configured?
      return fallback_analysis(message)
    end
    
    # OpenAI APIを使用して質問を分析
    analysis_prompt = <<~PROMPT
      以下のメッセージを分析して、含まれている質問を抽出してください。
      各質問について、以下の形式でJSONで返してください：
      {
        "questions": [
          {
            "content": "質問内容",
            "topic": "トピック（例：ECモール連携、セキュリティ、価格など）",
            "priority": "high/medium/low"
          }
        ],
        "main_intent": "ユーザーの主な意図",
        "requires_detailed_answer": true/false
      }

      メッセージ：
      #{message}
    PROMPT

    response = @openai_service.analyze_with_gpt4(analysis_prompt)
    JSON.parse(response)
  rescue StandardError => e
    Rails.logger.error "Message analysis failed: #{e.message}"
    fallback_analysis(message)
  end

  # 複数の質問に対して個別に回答を生成
  def generate_natural_response(user_message, conversation_history, context = {})
    Rails.logger.info "[NaturalConversation] Starting response generation"
    Rails.logger.info "  - User message: #{user_message}"
    Rails.logger.info "  - Context: #{context.inspect}"
    
    begin
      Rails.logger.info "[NaturalConversation] Step 1: Analyzing message"
      analysis = analyze_message(user_message)
      Rails.logger.info "[NaturalConversation] Analysis result: #{analysis.inspect}"
      
      if analysis['questions'].size > 1
        Rails.logger.info "[NaturalConversation] Multiple questions detected: #{analysis['questions'].size}"
        # 複数質問への対応
        response = handle_multiple_questions(analysis, conversation_history, context)
      else
        Rails.logger.info "[NaturalConversation] Single question detected"
        # 単一質問への対応
        response = handle_single_question(user_message, conversation_history, context)
      end
      
      Rails.logger.info "[NaturalConversation] Response generated, length: #{response&.length}"
      
      # 空の応答をチェック
      if response.nil? || response.strip.empty?
        Rails.logger.warn "[NaturalConversation] Empty response, using fallback"
        return fallback_simple_response(user_message, context)
      end
      
      response
    rescue StandardError => e
      Rails.logger.error "[NaturalConversation] Response generation failed: #{e.message}"
      Rails.logger.error "  - Backtrace: #{e.backtrace.first(3).join("\n")}"
      fallback_simple_response(user_message, context)
    end
  end

  private

  # 複数の質問に対する回答を生成
  def handle_multiple_questions(analysis, conversation_history, context)
    questions = analysis['questions']
    
    # 各質問に対する回答を生成
    responses = questions.map do |question|
      generate_specific_answer(question, conversation_history, context)
    end

    # 自然な形で結合
    combine_responses(responses, questions)
  end

  # 個別の質問に対する具体的な回答を生成
  def generate_specific_answer(question, conversation_history, context)
    # 優先度が高い質問はClaude、それ以外はOpenAIを使用
    if question['priority'] == 'high'
      compacted = @claude_service.generate_response(conversation_history, question['content'])
      @claude_service.compact_text(compacted)
    else
      # OpenAIサービスも同様に呼び出す（OpenAIサービスの実装に合わせて調整）
      @claude_service.compact_text(@openai_service.generate_response(question['content']))
    end
  end

  # 回答用のプロンプトを構築
  def build_answer_prompt(question, conversation_history, context)
    company_knowledge = CompanyKnowledgeService.new.get_relevant_info(question['content'])
    
    <<~PROMPT
      以下の質問に対して、具体的で実用的な回答を生成してください。

      ## 質問
      #{question['content']}

      ## トピック
      #{question['topic']}

      ## 会社情報
      #{company_knowledge.to_json}

      ## 会話履歴
      #{format_conversation_history(conversation_history)}

      ## 回答の要件
      - 具体的な仕様や機能について明確に答える
      - 「はい/いいえ」で答えられる質問は明確に答える
      - 技術的な詳細も含める
      - 営業的すぎない自然な口調で
      - 必要に応じて例を示す
    PROMPT
  end

  # 複数の回答を自然に結合
  def combine_responses(responses, questions)
    intro = generate_intro(questions)
    
    formatted_responses = responses.map.with_index do |response, index|
      question_topic = questions[index]['topic']
      
      # トピックごとに見出しを付ける
      <<~SECTION
        【#{question_topic}について】
        #{response}
      SECTION
    end.join("\n")
    
    outro = generate_outro(questions)
    
    [intro, formatted_responses, outro].compact.join("\n\n")
  end

  # 導入文を生成
  def generate_intro(questions)
    topics = questions.map { |q| q['topic'] }.join('と')
    
    if questions.size > 1
      "#{topics}について、順番にお答えいたします。"
    else
      nil
    end
  end

  # 締めの文を生成
  def generate_outro(questions)
    high_priority_count = questions.count { |q| q['priority'] == 'high' }
    
    if high_priority_count > 0
      "これらの機能について、さらに詳しい仕様や導入事例をご説明できます。\n具体的な要件がございましたら、お聞かせください。"
    else
      "ご不明な点がございましたら、お気軽にお問い合わせください。"
    end
  end

  # 単一の質問への対応
  def handle_single_question(message, conversation_history, context)
    # まずは挨拶を即時ハンドリング（外部APIに依存しない）
    if greeting_message?(message)
      return build_greeting_response(message)
    end

    # Claude APIは conversation_history と user_message の2つの引数を期待している
    Rails.logger.info "[NaturalConversation] Calling Claude API with history: #{conversation_history.inspect}"
    Rails.logger.info "[NaturalConversation] Message: #{message}"
    
    response = @claude_service.generate_response(conversation_history, message)
    response = @claude_service.compact_text(response)
    
    Rails.logger.info "[NaturalConversation] Claude API response class: #{response.class}"
    Rails.logger.info "[NaturalConversation] Claude API response: #{response.inspect}"
    
    response
  end

  # シンプルな挨拶判定
  def greeting_message?(text)
    return false unless text
    normalized = text.to_s.strip
    !!(normalized.match(/^(こん(にちは|ばんは)|おはよう|hello|hi|hey)/i))
  end

  # 挨拶に対する自然な返答（時間帯などに応じて将来拡張可）
  def build_greeting_response(text)
    case text
    when /こんばんは/i
      'こんばんは！本日はどのようなご相談でしょうか？'
    when /おはよう/i
      'おはようございます！本日もよろしくお願いいたします。どのような内容でお手伝いできますか？'
    when /こん(にちは)/i
      'こんにちは！どのような点について知りたいですか？'
    else
      'こんにちは！お手伝いできることがあればお知らせください。'
    end
  end

  # 会話履歴をフォーマット
  def format_conversation_history(history)
    return "（新規会話）" if history.empty?
    
    history.last(5).map do |msg|
      role = msg[:role] == 'user' ? 'ユーザー' : 'アシスタント'
      "#{role}: #{msg[:content]}"
    end.join("\n")
  end

  # フォールバック分析
  def fallback_analysis(message)
    # 簡単なパターンマッチングで質問を検出
    questions = message.split(/[？?。]/).map(&:strip).reject(&:empty?)
    
    {
      'questions' => questions.map do |q|
        {
          'content' => q,
          'topic' => detect_topic(q),
          'priority' => 'medium'
        }
      end,
      'main_intent' => 'information_request',
      'requires_detailed_answer' => true
    }
  end

  # トピックを検出
  def detect_topic(text)
    case text
    when /連携|API|統合/
      'システム連携'
    when /セキュリティ|保護|暗号/
      'セキュリティ'
    when /価格|料金|費用/
      '料金'
    when /納期|期間|スケジュール/
      'スケジュール'
    else
      '一般'
    end
  end

  # APIキーが設定されているか確認
  def api_keys_configured?
    openai_key = Rails.application.credentials.dig(:openai, :api_key) || ENV['OPENAI_API_KEY']
    claude_key = Rails.application.credentials.dig(:anthropic, :api_key) || ENV['ANTHROPIC_API_KEY']
    
    openai_key.present? && claude_key.present?
  end

  # シンプルなフォールバック応答
  def fallback_simple_response(user_message, context = {})
    if user_message.include?('連携') && user_message.include?('セキュリティ')
      <<~RESPONSE
        ECモール連携とセキュリティについて、順番にお答えいたします。

        【ECモール連携について】
        楽天市場、Amazon、Yahoo!ショッピングの主要3モールとの連携に対応しています。
        - 商品情報の一括管理と同期
        - 在庫の自動更新機能
        - 注文データの統合管理
        - 各モールのAPIを活用した効率的な運用

        【セキュリティ対策について】
        お客様の大切な情報を守るため、以下の対策を実施しています：
        - SSL/TLS暗号化通信（256bit）
        - WAF（Webアプリケーションファイアウォール）導入
        - ISO27001準拠のセキュリティ管理体制
        - 定期的な脆弱性診断とペネトレーションテスト
        - 個人情報保護法およびGDPRに準拠した運用

        より詳しい仕様や導入事例について説明が必要でしたら、お聞かせください。
      RESPONSE
    elsif user_message.include?('連携')
      <<~RESPONSE
        ECモール連携について回答いたします。

        主要ECモール（楽天市場、Amazon、Yahoo!ショッピング）との連携に対応しており、
        商品管理、在庫同期、注文処理を一元化できます。

        APIを活用した自動連携により、運用工数を大幅に削減可能です。
        具体的な連携要件がございましたら、お聞かせください。
      RESPONSE
    elsif user_message.include?('セキュリティ')
      <<~RESPONSE
        セキュリティ対策について回答いたします。

        SSL/TLS暗号化、WAF導入、ISO27001準拠の体制で
        お客様の情報を安全に保護します。

        定期的な脆弱性診断も実施しており、
        最新のセキュリティ脅威にも対応しています。

        詳細なセキュリティ要件がございましたら、お聞かせください。
      RESPONSE
    else
      <<~RESPONSE
        ご質問ありがとうございます。

        お客様のご要望に合わせたソリューションをご提供いたします。
        より具体的なご要望をお聞かせいただければ、
        最適なご提案をさせていただきます。

        技術的な詳細についても、お気軽にお問い合わせください。
      RESPONSE
    end
  end
end