# frozen_string_literal: true

class SemanticSimilarityService
  EMBEDDING_DIMENSION = 1536
  DEFAULT_K_NEIGHBORS = 5
  DEFAULT_THRESHOLD = 0.7
  
  def initialize
    @vector_service = VectorSearchService.new
    @cache = {}
  end
  
  # コサイン類似度を計算
  def calculate_similarity(vec1, vec2)
    return 0.0 if vec1.nil? || vec2.nil?
    return 0.0 if vec1.size != vec2.size
    
    # ゼロベクトルチェック
    return 0.0 if vec1.all?(&:zero?) || vec2.all?(&:zero?)
    
    # コサイン類似度の計算
    dot_product = vec1.zip(vec2).sum { |a, b| a * b }
    norm1 = Math.sqrt(vec1.sum { |x| x * x })
    norm2 = Math.sqrt(vec2.sum { |x| x * x })
    
    return 0.0 if norm1 == 0 || norm2 == 0
    
    dot_product / (norm1 * norm2)
  end
  
  # テキストの意味的類似度を計算
  def semantic_similarity(text1, text2)
    # ベクトル埋め込みを生成
    embedding1 = get_or_generate_embedding(text1)
    embedding2 = get_or_generate_embedding(text2)
    
    # コサイン類似度を計算
    similarity = calculate_similarity(embedding1, embedding2)
    
    # 0から1の範囲に正規化（コサイン類似度は-1から1）
    (similarity + 1) / 2
  end
  
  # 意味的に近いメッセージを検索
  def find_semantic_neighbors(query, k: DEFAULT_K_NEIGHBORS, radius: nil)
    query_embedding = get_or_generate_embedding(query)
    
    # すべてのメッセージとの類似度を計算
    messages_with_scores = Message.where.not(embedding: nil).map do |message|
      similarity = calculate_similarity(query_embedding, message.embedding)
      { message: message, similarity: similarity, distance: 1.0 - similarity }
    end
    
    # 距離閾値でフィルタリング
    if radius
      messages_with_scores = messages_with_scores.select { |item| item[:distance] <= radius }
    end
    
    # 類似度でソートしてトップKを返す
    messages_with_scores
      .sort_by { |item| -item[:similarity] }
      .first(k)
      .map { |item| item[:message] }
  end
  
  # 文書の類似度を計算
  def calculate_document_similarity(doc1, doc2, detailed: false)
    if detailed
      # 文単位で詳細な類似度を計算
      sentences1 = split_into_sentences(doc1)
      sentences2 = split_into_sentences(doc2)
      
      sentence_pairs = []
      sentences1.each do |s1|
        sentences2.each do |s2|
          similarity = semantic_similarity(s1, s2)
          sentence_pairs << { sentence1: s1, sentence2: s2, similarity: similarity }
        end
      end
      
      avg_similarity = sentence_pairs.sum { |p| p[:similarity] } / sentence_pairs.size.to_f
      
      {
        score: avg_similarity,
        confidence: calculate_confidence(sentence_pairs),
        sentence_pairs: sentence_pairs.sort_by { |p| -p[:similarity] }.first(5),
        average_similarity: avg_similarity
      }
    else
      # 文書全体の類似度
      similarity = semantic_similarity(doc1, doc2)
      
      {
        score: similarity,
        confidence: similarity > 0.5 ? 'high' : 'low'
      }
    end
  end
  
  # 類似度でクラスタリング
  def cluster_by_similarity(messages, n_clusters: 3)
    return [] if messages.empty?
    
    # K-meansクラスタリング
    clusters = perform_kmeans(messages, n_clusters)
    
    clusters.map do |cluster|
      centroid = calculate_centroid(cluster.map(&:embedding))
      
      {
        members: cluster,
        centroid: centroid,
        label: generate_cluster_label(cluster),
        cohesion: calculate_cluster_cohesion(cluster)
      }
    end
  end
  
  # 階層的クラスタリング
  def hierarchical_clustering(messages)
    return { tree: [], levels: [], optimal_clusters: 0 } if messages.empty?
    
    # 距離行列を計算
    distance_matrix = calculate_distance_matrix(messages)
    
    # 階層的クラスタリングを実行
    tree = build_hierarchical_tree(messages, distance_matrix)
    
    # 最適なクラスタ数を決定
    optimal = determine_optimal_clusters(tree, messages.size)
    
    {
      tree: tree,
      levels: extract_levels(tree),
      optimal_clusters: optimal
    }
  end
  
  # 意味的検索
  def semantic_search(query, index: 'messages')
    query_embedding = get_or_generate_embedding(query)
    results = []
    
    if index.is_a?(Array)
      # 複数インデックスを検索
      index.each do |idx|
        results.concat(search_single_index(query_embedding, idx))
      end
    else
      results = search_single_index(query_embedding, index)
    end
    
    # スコアでソート
    results.sort_by { |r| -r[:score] }
  end
  
  # 埋め込みベクトル間の距離を計算
  def calculate_embedding_distance(vec1, vec2, metric: 'cosine')
    case metric
    when 'euclidean'
      Math.sqrt(vec1.zip(vec2).sum { |a, b| (a - b)**2 })
    when 'manhattan'
      vec1.zip(vec2).sum { |a, b| (a - b).abs }
    when 'cosine'
      1.0 - calculate_similarity(vec1, vec2)
    else
      raise ArgumentError, "Unknown metric: #{metric}"
    end
  end
  
  # 重み付き類似度
  def weighted_similarity(vec1, vec2, weights = nil, context: nil)
    if context
      weights = generate_weights_from_context(vec1.size, context)
    elsif weights.nil?
      weights = Array.new(vec1.size, 1.0 / vec1.size)
    end
    
    # 重みを正規化
    weight_sum = weights.sum
    normalized_weights = weights.map { |w| w / weight_sum }
    
    # 重み付きベクトルを作成
    weighted_vec1 = vec1.zip(normalized_weights).map { |v, w| v * Math.sqrt(w) }
    weighted_vec2 = vec2.zip(normalized_weights).map { |v, w| v * Math.sqrt(w) }
    
    # 通常のコサイン類似度を計算
    calculate_similarity(weighted_vec1, weighted_vec2)
  end
  
  # 異常検出
  def find_anomalies(threshold: 0.8)
    messages = Message.where.not(embedding: nil)
    return [] if messages.empty?
    
    # 各メッセージの異常スコアを計算
    scores = calculate_anomaly_scores
    
    # 閾値を超えるものを異常として検出
    anomalies = scores.select { |s| s[:is_anomaly] }
                     .map { |s| s[:message] }
    
    anomalies
  end
  
  # 異常スコアを計算
  def calculate_anomaly_scores
    messages = Message.where.not(embedding: nil)
    return [] if messages.empty?
    
    # 全体の重心を計算
    centroid = calculate_centroid(messages.map(&:embedding))
    
    # 各メッセージの異常スコアを計算
    scores = messages.map do |message|
      distance = calculate_embedding_distance(message.embedding, centroid, metric: 'euclidean')
      
      # 平均距離と標準偏差を使って異常判定
      {
        message: message,
        score: distance,
        is_anomaly: distance > calculate_anomaly_threshold(messages, centroid)
      }
    end
    
    scores
  end
  
  # 類似度行列を生成
  def similarity_matrix(items, sparse: false)
    n = items.size
    
    if sparse
      # スパース行列として保存
      indices = []
      values = []
      
      items.each_with_index do |item1, i|
        items.each_with_index do |item2, j|
          if i <= j  # 対称行列なので半分だけ計算
            similarity = calculate_similarity(item1.embedding, item2.embedding)
            if similarity.abs > 0.01  # 小さい値は無視
              indices << [i, j]
              values << similarity
              if i != j
                indices << [j, i]
                values << similarity
              end
            end
          end
        end
      end
      
      { indices: indices, values: values, shape: [n, n] }
    else
      # 密行列として生成
      matrix = Array.new(n) { Array.new(n, 0.0) }
      
      items.each_with_index do |item1, i|
        items.each_with_index do |item2, j|
          matrix[i][j] = calculate_similarity(item1.embedding, item2.embedding)
        end
      end
      
      matrix
    end
  end
  
  # 意味的補間
  def semantic_interpolation(vec1, vec2, alpha: 0.5, steps: nil)
    if steps
      # 複数ステップで補間
      path = []
      (0...steps).each do |i|
        t = i.to_f / (steps - 1)
        interpolated = vec1.zip(vec2).map { |a, b| a * (1 - t) + b * t }
        path << interpolated
      end
      path
    else
      # 単一の補間点
      vec1.zip(vec2).map { |a, b| a * (1 - alpha) + b * alpha }
    end
  end
  
  # バッチ類似度計算
  def batch_similarity(vectors1, vectors2, batch_size: 100)
    n1 = vectors1.size
    n2 = vectors2.size
    similarities = Array.new(n1) { Array.new(n2, 0.0) }
    
    # バッチ処理
    vectors1.each_slice(batch_size).with_index do |batch1, bi|
      vectors2.each_slice(batch_size).with_index do |batch2, bj|
        batch1.each_with_index do |vec1, i|
          batch2.each_with_index do |vec2, j|
            similarities[bi * batch_size + i][bj * batch_size + j] = 
              calculate_similarity(vec1, vec2)
          end
        end
      end
    end
    
    similarities
  end
  
  private
  
  # 埋め込みを取得または生成
  def get_or_generate_embedding(text)
    @cache[text] ||= @vector_service.generate_embedding(text)
  end
  
  # 文に分割
  def split_into_sentences(text)
    text.split(/[。！？\n]/).reject(&:empty?)
  end
  
  # 信頼度を計算
  def calculate_confidence(sentence_pairs)
    high_similarity_count = sentence_pairs.count { |p| p[:similarity] > 0.7 }
    high_similarity_count.to_f / sentence_pairs.size
  end
  
  # K-meansを実行
  def perform_kmeans(messages, n_clusters)
    return [messages] if n_clusters == 1
    
    # 初期中心点をランダムに選択
    centroids = messages.sample(n_clusters).map(&:embedding)
    clusters = nil
    
    10.times do
      # 各メッセージを最も近い中心に割り当て
      new_clusters = Array.new(n_clusters) { [] }
      
      messages.each do |message|
        distances = centroids.map { |c| calculate_embedding_distance(message.embedding, c) }
        nearest_idx = distances.index(distances.min)
        new_clusters[nearest_idx] << message
      end
      
      # 空のクラスタを除去
      new_clusters.reject!(&:empty?)
      
      # 中心を更新
      centroids = new_clusters.map { |cluster| calculate_centroid(cluster.map(&:embedding)) }
      clusters = new_clusters
    end
    
    clusters
  end
  
  # 重心を計算
  def calculate_centroid(embeddings)
    return nil if embeddings.empty?
    
    dimension = embeddings.first.size
    centroid = Array.new(dimension, 0.0)
    
    embeddings.each do |embedding|
      embedding.each_with_index do |val, i|
        centroid[i] += val
      end
    end
    
    centroid.map { |sum| sum / embeddings.size }
  end
  
  # クラスタラベルを生成
  def generate_cluster_label(messages)
    # 最頻出の単語をラベルとして使用
    words = messages.flat_map { |m| m.content.split(/\s+/) }
    word_counts = words.group_by(&:itself).transform_values(&:count)
    most_common = word_counts.max_by { |_, count| count }
    
    most_common ? most_common[0] : 'クラスタ'
  end
  
  # クラスタの凝集度を計算
  def calculate_cluster_cohesion(messages)
    return 1.0 if messages.size <= 1
    
    embeddings = messages.map(&:embedding)
    centroid = calculate_centroid(embeddings)
    
    # 平均距離を計算
    avg_distance = embeddings.sum { |e| calculate_embedding_distance(e, centroid) } / embeddings.size
    
    # 凝集度スコア（距離が小さいほど高い）
    1.0 / (1.0 + avg_distance)
  end
  
  # 距離行列を計算
  def calculate_distance_matrix(messages)
    n = messages.size
    matrix = Array.new(n) { Array.new(n, 0.0) }
    
    messages.each_with_index do |msg1, i|
      messages.each_with_index do |msg2, j|
        if i < j
          distance = calculate_embedding_distance(msg1.embedding, msg2.embedding)
          matrix[i][j] = distance
          matrix[j][i] = distance
        end
      end
    end
    
    matrix
  end
  
  # 階層的木を構築
  def build_hierarchical_tree(messages, distance_matrix)
    # 簡略化された実装
    tree = []
    n = messages.size
    
    # 各メッセージを葉ノードとして初期化
    clusters = messages.map.with_index { |msg, i| { id: i, members: [msg] } }
    
    while clusters.size > 1
      # 最も近いクラスタペアを見つける
      min_dist = Float::INFINITY
      merge_i, merge_j = 0, 1
      
      clusters.each_with_index do |c1, i|
        clusters.each_with_index do |c2, j|
          next if i >= j
          
          # クラスタ間の平均距離
          dist = calculate_cluster_distance(c1[:members], c2[:members])
          if dist < min_dist
            min_dist = dist
            merge_i, merge_j = i, j
          end
        end
      end
      
      # クラスタをマージ
      new_cluster = {
        id: tree.size + n,
        members: clusters[merge_i][:members] + clusters[merge_j][:members],
        distance: min_dist
      }
      
      tree << { left: clusters[merge_i], right: clusters[merge_j], distance: min_dist }
      
      # クラスタリストを更新
      clusters.delete_at([merge_i, merge_j].max)
      clusters.delete_at([merge_i, merge_j].min)
      clusters << new_cluster
    end
    
    tree
  end
  
  # クラスタ間距離を計算
  def calculate_cluster_distance(cluster1, cluster2)
    distances = []
    
    cluster1.each do |msg1|
      cluster2.each do |msg2|
        distances << calculate_embedding_distance(msg1.embedding, msg2.embedding)
      end
    end
    
    distances.sum / distances.size  # 平均距離
  end
  
  # レベルを抽出
  def extract_levels(tree)
    tree.map { |node| node[:distance] }.uniq.sort
  end
  
  # 最適なクラスタ数を決定
  def determine_optimal_clusters(tree, total_items)
    # エルボー法の簡略版
    return 3 if total_items > 10
    return 2 if total_items > 5
    1
  end
  
  # 単一インデックスを検索
  def search_single_index(query_embedding, index_name)
    results = []
    
    case index_name
    when 'messages'
      Message.where.not(embedding: nil).each do |message|
        score = calculate_similarity(query_embedding, message.embedding)
        results << {
          item: message,
          type: 'message',
          score: score,
          explanation: "メッセージ: #{message.content[0..50]}"
        }
      end
    when 'knowledge_base'
      KnowledgeBase.where.not(embedding: nil).each do |kb|
        score = calculate_similarity(query_embedding, kb.embedding)
        results << {
          item: kb,
          type: 'knowledge_base',
          score: score,
          explanation: "ナレッジ: #{kb.summary || kb.content.to_s[0..50]}"
        }
      end
    end
    
    results
  end
  
  # コンテキストから重みを生成
  def generate_weights_from_context(dimension, context)
    weights = Array.new(dimension, 1.0 / dimension)
    
    # コンテキストに基づいて重みを調整（簡略化）
    if context[:focus] == 'technical'
      # 技術的な次元により高い重みを付ける（仮想的な実装）
      weights[0..dimension/2] = weights[0..dimension/2].map { |w| w * 1.5 }
    end
    
    # 正規化
    sum = weights.sum
    weights.map { |w| w / sum }
  end
  
  # 異常閾値を計算
  def calculate_anomaly_threshold(messages, centroid)
    distances = messages.map { |m| calculate_embedding_distance(m.embedding, centroid) }
    
    mean = distances.sum / distances.size
    variance = distances.sum { |d| (d - mean)**2 } / distances.size
    std_dev = Math.sqrt(variance)
    
    # 平均 + 2標準偏差を閾値とする
    mean + 2 * std_dev
  end
end