# frozen_string_literal: true

class VectorSearchService
  EMBEDDING_DIMENSION = 1536
  DEFAULT_BATCH_SIZE = 50
  DEFAULT_SIMILARITY_THRESHOLD = 0.3
  
  def initialize
    @cache = {}
    @embedding_service = OpenaiEmbeddingService.new
  end
  
  # テキストからベクトル埋め込みを生成
  def generate_embedding(text)
    return Array.new(EMBEDDING_DIMENSION, 0.0) if text.blank?
    
    # キャッシュチェック
    cached = @cache[text]
    return cached if cached.present?
    
    # OpenAI APIを使用してembeddingを生成
    embedding = @embedding_service.generate_embedding(text)
    
    # キャッシュに保存
    @cache[text] = embedding
    
    embedding
  rescue StandardError => e
    Rails.logger.error "Failed to generate embedding: #{e.message}"
    # フォールバックとしてモック実装を使用
    embedding = generate_mock_embedding(text)
    @cache[text] = embedding
    embedding
  end
  
  # メッセージのベクトル埋め込みを保存
  def store_message_embedding(message)
    embedding = generate_embedding(message.content)
    message.update!(embedding: embedding)
    true
  rescue StandardError => e
    Rails.logger.error "Failed to store embedding: #{e.message}"
    false
  end
  
  # 類似メッセージを検索
  def find_similar_messages(query, limit: 10, threshold: DEFAULT_SIMILARITY_THRESHOLD)
    query_embedding = generate_embedding(query)
    
    # PostgreSQLでコサイン類似度を計算して検索
    messages_with_scores = Message.where.not(embedding: nil).map do |message|
      score = calculate_similarity(query_embedding, message.embedding)
      { message: message, score: score }
    end
    
    # スコアでフィルタリングとソート
    messages_with_scores
      .select { |item| item[:score] >= threshold }
      .sort_by { |item| -item[:score] }
      .first(limit)
      .map { |item| item[:message] }
  end
  
  # スコア付きで類似メッセージを検索
  def find_similar_messages_with_scores(query, limit: 10)
    query_embedding = generate_embedding(query)
    
    messages_with_scores = Message.where.not(embedding: nil).map do |message|
      score = calculate_similarity(query_embedding, message.embedding)
      distance = 1.0 - score  # コサイン距離
      {
        message: message,
        score: score,
        distance: distance
      }
    end
    
    messages_with_scores
      .sort_by { |item| -item[:score] }
      .first(limit)
  end
  
  # 類似の会話を検索
  def find_similar_conversations(query, limit: 10)
    query_embedding = generate_embedding(query)
    
    # 会話ごとにメッセージの平均ベクトルを計算
    conversations_with_scores = Conversation.joins(:messages)
                                           .group('conversations.id')
                                           .map do |conversation|
      embeddings = conversation.messages.where.not(embedding: nil).pluck(:embedding)
      next if embeddings.empty?
      
      # 平均ベクトルを計算
      avg_embedding = calculate_average_embedding(embeddings)
      score = calculate_similarity(query_embedding, avg_embedding)
      
      { conversation: conversation, score: score }
    end.compact
    
    conversations_with_scores
      .sort_by { |item| -item[:score] }
      .first(limit)
      .map { |item| item[:conversation] }
  end
  
  # スコア付きで類似会話を検索
  def find_similar_conversations_with_scores(query)
    query_embedding = generate_embedding(query)
    
    conversations_with_scores = Conversation.joins(:messages)
                                           .group('conversations.id')
                                           .map do |conversation|
      embeddings = conversation.messages.where.not(embedding: nil).pluck(:embedding)
      next if embeddings.empty?
      
      avg_embedding = calculate_average_embedding(embeddings)
      score = calculate_similarity(query_embedding, avg_embedding)
      
      {
        conversation: conversation,
        average_score: score
      }
    end.compact
    
    conversations_with_scores.sort_by { |item| -item[:average_score] }
  end
  
  # ナレッジベースから検索
  def search_knowledge_base(query, limit: 10, tags: nil)
    query_embedding = generate_embedding(query)
    
    scope = KnowledgeBase.where.not(embedding: nil)
    scope = scope.where("tags && ARRAY[?]::varchar[]", tags) if tags.present?
    
    patterns_with_scores = scope.map do |pattern|
      score = calculate_similarity(query_embedding, pattern.embedding)
      { pattern: pattern, score: score }
    end
    
    patterns_with_scores
      .sort_by { |item| -item[:score] }
      .first(limit)
      .map { |item| item[:pattern] }
  end
  
  # バッチでベクトルを生成
  def batch_generate_embeddings(texts, batch_size: DEFAULT_BATCH_SIZE)
    # OpenAI APIの場合は直接バッチ処理を使用
    begin
      @embedding_service.generate_embeddings(texts)
    rescue StandardError => e
      Rails.logger.error "Batch embedding generation failed: #{e.message}"
      # フォールバックとして個別処理
      embeddings = []
      texts.each_slice(batch_size) do |batch|
        batch_embeddings = batch.map { |text| generate_embedding(text) }
        embeddings.concat(batch_embeddings)
      end
      embeddings
    end
  end
  
  # すべてのメッセージの埋め込みを更新
  def update_all_embeddings(force: false)
    processed = 0
    skipped = 0
    errors = 0
    
    messages = force ? Message.all : Message.where(embedding: nil)
    
    messages.find_each do |message|
      if !force && message.embedding.present?
        skipped += 1
        next
      end
      
      if store_message_embedding(message)
        processed += 1
      else
        errors += 1
      end
    end
    
    {
      processed: processed,
      skipped: skipped,
      errors: errors
    }
  end
  
  # コサイン類似度を計算
  def calculate_similarity(vec1, vec2)
    return 0.0 if vec1.nil? || vec2.nil?
    return 0.0 if vec1.size != vec2.size
    
    dot_product = vec1.zip(vec2).sum { |a, b| a * b }
    norm1 = Math.sqrt(vec1.sum { |x| x * x })
    norm2 = Math.sqrt(vec2.sum { |x| x * x })
    
    return 0.0 if norm1 == 0 || norm2 == 0
    
    dot_product / (norm1 * norm2)
  end
  
  # メッセージをクラスタリング
  def clustering_messages(n_clusters: 3)
    messages_with_embeddings = Message.where.not(embedding: nil)
    return [] if messages_with_embeddings.empty?
    
    # K-meansクラスタリングの簡易実装
    clusters = perform_kmeans_clustering(messages_with_embeddings, n_clusters)
    
    # 各クラスタの情報を生成
    clusters.map do |cluster_messages|
      embeddings = cluster_messages.map(&:embedding)
      centroid = calculate_average_embedding(embeddings)
      
      # 重心に最も近いメッセージを代表として選択
      representative_messages = cluster_messages
        .map { |msg| { message: msg, distance: 1.0 - calculate_similarity(centroid, msg.embedding) } }
        .sort_by { |item| item[:distance] }
        .first(3)
        .map { |item| item[:message] }
      
      {
        messages: cluster_messages,
        centroid: centroid,
        label: generate_cluster_label(cluster_messages),
        representative_messages: representative_messages
      }
    end
  end
  
  private
  
  # モックのベクトル埋め込みを生成
  def generate_mock_embedding(text)
    # テキストのハッシュ値を基にした決定的な埋め込み生成
    hash_value = text.hash
    random_gen = Random.new(hash_value)
    
    # テキストの特徴に基づいて異なるパターンを生成
    base_pattern = if text.include?('ログイン') || text.include?('パスワード')
                     Array.new(EMBEDDING_DIMENSION) { |i| Math.sin(i * 0.1 + hash_value % 10 * 0.1) * 0.5 }
                   elsif text.include?('支払い') || text.include?('決済') || text.include?('請求')
                     Array.new(EMBEDDING_DIMENSION) { |i| Math.cos(i * 0.1 + hash_value % 10 * 0.1) * 0.5 }
                   elsif text.include?('注文') || text.include?('キャンセル')
                     Array.new(EMBEDDING_DIMENSION) { |i| Math.sin(i * 0.2 + hash_value % 10 * 0.1) * 0.5 }
                   elsif text.include?('配送') || text.include?('発送')
                     Array.new(EMBEDDING_DIMENSION) { |i| Math.cos(i * 0.2 + hash_value % 10 * 0.1) * 0.5 }
                   else
                     Array.new(EMBEDDING_DIMENSION) { random_gen.rand(-0.5..0.5) }
                   end
    
    # 正規化
    norm = Math.sqrt(base_pattern.sum { |x| x * x })
    base_pattern.map { |x| norm > 0 ? x / norm : x }
  end
  
  # 平均ベクトルを計算
  def calculate_average_embedding(embeddings)
    return nil if embeddings.empty?
    
    dimension = embeddings.first.size
    avg = Array.new(dimension, 0.0)
    
    embeddings.each do |embedding|
      embedding.each_with_index do |value, i|
        avg[i] += value
      end
    end
    
    avg.map { |sum| sum / embeddings.size }
  end
  
  # K-meansクラスタリングの簡易実装
  def perform_kmeans_clustering(messages, n_clusters)
    return [messages.to_a] if n_clusters == 1
    return [] if messages.empty?
    
    # 初期クラスタ中心をランダムに選択
    centroids = messages.sample(n_clusters).map(&:embedding)
    clusters = nil
    
    # 反復的にクラスタを更新（最大10回）
    10.times do
      # 各メッセージを最も近い中心に割り当て
      new_clusters = Array.new(n_clusters) { [] }
      
      messages.each do |message|
        distances = centroids.map { |centroid| 1.0 - calculate_similarity(message.embedding, centroid) }
        nearest_index = distances.index(distances.min)
        new_clusters[nearest_index] << message
      end
      
      # 空のクラスタを除去
      new_clusters.reject!(&:empty?)
      
      # クラスタ中心を更新
      centroids = new_clusters.map do |cluster|
        embeddings = cluster.map(&:embedding)
        calculate_average_embedding(embeddings)
      end
      
      clusters = new_clusters
    end
    
    clusters
  end
  
  # クラスタのラベルを生成
  def generate_cluster_label(messages)
    # メッセージ内容から頻出キーワードを抽出してラベルとする
    keywords = messages.flat_map { |msg| extract_keywords(msg.content) }
    
    # 最頻出キーワードをラベルとして使用
    keyword_counts = keywords.group_by(&:itself).transform_values(&:count)
    most_common = keyword_counts.max_by { |_, count| count }
    
    most_common ? most_common[0] : 'クラスタ'
  end
  
  # キーワード抽出
  def extract_keywords(text)
    # 簡易的なキーワード抽出
    keywords = []
    keywords << 'ログイン' if text.include?('ログイン')
    keywords << 'パスワード' if text.include?('パスワード')
    keywords << '支払い' if text.include?('支払い') || text.include?('決済')
    keywords << '注文' if text.include?('注文')
    keywords << 'キャンセル' if text.include?('キャンセル')
    keywords << '配送' if text.include?('配送') || text.include?('発送')
    keywords << 'エラー' if text.include?('エラー')
    keywords << 'その他' if keywords.empty?
    keywords
  end
end