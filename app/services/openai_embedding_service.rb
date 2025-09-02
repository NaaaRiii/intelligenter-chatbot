# frozen_string_literal: true

# OpenAI APIを使用してembeddingを生成するサービス
class OpenaiEmbeddingService
  class EmbeddingError < StandardError; end

  def initialize
    api_key = if Rails.env.test?
                'test_openai_api_key'
              else
                Rails.application.credentials.dig(:openai, :api_key) || ENV.fetch('OPENAI_API_KEY', nil)
              end

    @client = OpenAI::Client.new(access_token: api_key)
    @model = 'text-embedding-3-small' # 1536次元、高品質・低コスト
  end

  # テキストからembeddingを生成
  def generate_embedding(text)
    # テスト環境でも検証を実行
    validate_text(text)
    
    return generate_mock_embedding if Rails.env.test?
    
    response = @client.embeddings(
      parameters: {
        model: @model,
        input: truncate_text(text),
        encoding_format: 'float'
      }
    )

    embedding = extract_embedding(response)
    validate_embedding(embedding)
    
    embedding
  rescue StandardError => e
    Rails.logger.error "OpenAI Embedding Error: #{e.message}"
    raise EmbeddingError, "Embedding生成中にエラーが発生しました: #{e.message}"
  end

  # 複数のテキストを一括でembedding生成
  def generate_embeddings(texts)
    # テスト環境でも検証を実行
    validate_texts(texts)
    
    return texts.map { generate_mock_embedding } if Rails.env.test?
    
    # バッチサイズを制限（OpenAIの制限に合わせる）
    batch_size = 100
    results = []
    
    texts.each_slice(batch_size) do |batch|
      truncated_batch = batch.map { |text| truncate_text(text) }
      
      response = @client.embeddings(
        parameters: {
          model: @model,
          input: truncated_batch,
          encoding_format: 'float'
        }
      )
      
      batch_embeddings = extract_embeddings(response)
      results.concat(batch_embeddings)
    end
    
    results
  rescue StandardError => e
    Rails.logger.error "OpenAI Batch Embedding Error: #{e.message}"
    raise EmbeddingError, "バッチEmbedding生成中にエラーが発生しました: #{e.message}"
  end

  # embedding情報を取得
  def embedding_info
    {
      model: @model,
      dimensions: 1536,
      max_tokens: 8191,
      provider: 'openai'
    }
  end

  # モデルの詳細情報
  def model_info
    {
      name: @model,
      description: 'OpenAI text-embedding-3-small model',
      dimensions: 1536,
      cost_per_1k_tokens: 0.00002, # USD
      max_input_tokens: 8191
    }
  end

  private

  # テキストの検証
  def validate_text(text)
    raise EmbeddingError, 'テキストが空です' if text.blank?
    raise EmbeddingError, 'テキストが長すぎます' if text.length > 32768 # 約8K tokens
  end

  # 複数テキストの検証
  def validate_texts(texts)
    raise EmbeddingError, 'テキスト配列が空です' if texts.empty?
    raise EmbeddingError, 'バッチサイズが大きすぎます' if texts.size > 1000
    
    texts.each_with_index do |text, index|
      begin
        validate_text(text)
      rescue EmbeddingError => e
        raise EmbeddingError, "テキスト[#{index}]: #{e.message}"
      end
    end
  end

  # テキストを最大長に切り詰め
  def truncate_text(text)
    # 安全のため6000文字で切り詰め（約8K tokensの制限内）
    text.length > 6000 ? text[0, 6000] : text
  end

  # レスポンスからembeddingを抽出
  def extract_embedding(response)
    data = response.dig('data', 0)
    raise EmbeddingError, 'Embedding データが見つかりません' unless data
    
    embedding = data['embedding']
    raise EmbeddingError, 'Embedding ベクトルが見つかりません' unless embedding
    
    embedding
  end

  # レスポンスから複数のembeddingを抽出
  def extract_embeddings(response)
    data = response['data']
    raise EmbeddingError, 'Embedding データが見つかりません' unless data&.any?
    
    embeddings = data.map { |item| item['embedding'] }
    
    # 全てのembeddingが存在することを確認
    if embeddings.any?(&:nil?)
      raise EmbeddingError, '一部のEmbedding ベクトルが見つかりません'
    end
    
    embeddings
  end

  # embeddingの検証
  def validate_embedding(embedding)
    unless embedding.is_a?(Array)
      raise EmbeddingError, 'Embedding は配列である必要があります'
    end
    
    unless embedding.size == 1536
      raise EmbeddingError, "Embedding の次元数が不正です。期待値: 1536, 実際: #{embedding.size}"
    end
    
    unless embedding.all? { |v| v.is_a?(Numeric) }
      raise EmbeddingError, 'Embedding の要素は全て数値である必要があります'
    end
  end

  # テスト用のモックembedding生成
  def generate_mock_embedding
    # 正規化されたランダムベクトルを生成
    vector = Array.new(1536) { rand(-1.0..1.0) }
    
    # L2正規化
    magnitude = Math.sqrt(vector.sum { |v| v**2 })
    vector.map { |v| v / magnitude }
  end
end