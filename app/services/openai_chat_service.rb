# frozen_string_literal: true

# OpenAI Chat APIを使用した会話生成サービス
class OpenaiChatService
  def initialize
    api_key = if Rails.env.test?
                'test_openai_api_key'
              else
                Rails.application.credentials.dig(:openai, :api_key) || ENV.fetch('OPENAI_API_KEY', nil)
              end

    @client = OpenAI::Client.new(access_token: api_key)
  end

  # GPT-4を使用してメッセージを分析
  def analyze_with_gpt4(prompt)
    return mock_analysis_response if Rails.env.test?

    response = @client.chat(
      parameters: {
        model: 'gpt-4-turbo-preview',
        messages: [
          {
            role: 'system',
            content: 'あなたは高度な自然言語処理の専門家です。JSONフォーマットで構造化された分析を提供してください。'
          },
          {
            role: 'user',
            content: prompt
          }
        ],
        temperature: 0.3,
        max_tokens: 500,
        response_format: { type: 'json_object' }
      }
    )

    extract_content(response)
  rescue StandardError => e
    Rails.logger.error "OpenAI GPT-4 Analysis Error: #{e.message}"
    raise
  end

  # GPT-3.5を使用して応答を生成
  def generate_response(prompt)
    return mock_chat_response if Rails.env.test?

    response = @client.chat(
      parameters: {
        model: 'gpt-3.5-turbo',
        messages: [
          {
            role: 'system',
            content: system_prompt
          },
          {
            role: 'user',
            content: prompt
          }
        ],
        temperature: 0.7,
        max_tokens: 1000
      }
    )

    extract_content(response)
  rescue StandardError => e
    Rails.logger.error "OpenAI Chat Error: #{e.message}"
    fallback_response
  end

  # ストリーミング応答を生成
  def generate_streaming_response(prompt, &block)
    return if Rails.env.test?

    @client.chat(
      parameters: {
        model: 'gpt-3.5-turbo',
        messages: [
          {
            role: 'system',
            content: system_prompt
          },
          {
            role: 'user',
            content: prompt
          }
        ],
        temperature: 0.7,
        max_tokens: 1000,
        stream: proc do |chunk|
          content = chunk.dig('choices', 0, 'delta', 'content')
          block.call(content) if content
        end
      }
    )
  rescue StandardError => e
    Rails.logger.error "OpenAI Streaming Error: #{e.message}"
    block.call(fallback_response)
  end

  # 会話履歴を含む応答生成
  def generate_with_history(messages, user_message)
    return mock_chat_response if Rails.env.test?

    formatted_messages = [
      { role: 'system', content: system_prompt }
    ]

    # 会話履歴を追加
    messages.each do |msg|
      formatted_messages << {
        role: msg[:role] == 'user' ? 'user' : 'assistant',
        content: msg[:content]
      }
    end

    # 最新のメッセージを追加
    formatted_messages << {
      role: 'user',
      content: user_message
    }

    response = @client.chat(
      parameters: {
        model: 'gpt-3.5-turbo',
        messages: formatted_messages,
        temperature: 0.7,
        max_tokens: 1000
      }
    )

    extract_content(response)
  rescue StandardError => e
    Rails.logger.error "OpenAI Chat with History Error: #{e.message}"
    fallback_response
  end

  private

  # システムプロンプト
  def system_prompt
    <<~PROMPT
      あなたはDataPro Solutions株式会社のカスタマーサポートAIアシスタントです。
      以下のガイドラインに従って応答してください：

      1. 親切で専門的な口調を保つ
      2. 質問には具体的に答える
      3. 技術的な内容も分かりやすく説明する
      4. 必要に応じて例を提供する
      5. 不明な点は確認を求める

      会社の主要サービス：
      - デジタルマーケティング支援
      - データ分析とビジネスインテリジェンス
      - ECサイト構築・運用支援
      - システム統合とAPI開発
    PROMPT
  end

  # レスポンスからコンテンツを抽出
  def extract_content(response)
    content = response.dig('choices', 0, 'message', 'content')
    raise 'No content in response' unless content
    
    content
  end

  # フォールバック応答
  def fallback_response
    <<~RESPONSE
      申し訳ございません。現在システムに一時的な問題が発生しています。
      しばらくしてから再度お試しいただくか、サポートチームまでお問い合わせください。
    RESPONSE
  end

  # テスト用モック分析応答
  def mock_analysis_response
    {
      questions: [
        {
          content: 'テスト質問',
          topic: 'テスト',
          priority: 'medium'
        }
      ],
      main_intent: 'test',
      requires_detailed_answer: true
    }.to_json
  end

  # テスト用モックチャット応答
  def mock_chat_response
    'これはテスト応答です。実際の環境では、OpenAI APIを使用して自然な応答が生成されます。'
  end
end