# frozen_string_literal: true

class RagService
  attr_reader :vector_service, :semantic_service, :cache
  
  def initialize
    @vector_service = VectorSearchService.new
    @semantic_service = SemanticSimilarityService.new
    @cache = {}
    @cache_timestamps = {}
  end
  
  # 新規問い合わせ時に類似3件を自動取得
  def retrieve_context(query, conversation: nil, limit: 3, threshold: 0.7, use_cache: false, cache_ttl: 300)
    # キャッシュチェック
    if use_cache && cached_context_valid?(query, cache_ttl)
      return @cache[query]
    end
    
    # 類似メッセージを検索
    similar_messages = @vector_service.find_similar_messages_with_scores(
      query, 
      limit: limit
    )
    
    # 閾値フィルタリング
    filtered_messages = similar_messages.select { |m| m[:score] >= threshold }
    
    # 解決策を抽出
    relevant_solutions = extract_solutions(filtered_messages)
    
    # コンテキストサマリを生成
    context_summary = generate_context_summary(filtered_messages, relevant_solutions)
    
    result = {
      query: query,
      retrieved_messages: filtered_messages,
      relevant_solutions: relevant_solutions,
      context_summary: context_summary
    }
    
    # キャッシュに保存
    if use_cache
      @cache[query] = result
      @cache_timestamps[query] = Time.current
    end
    
    result
  end
  
  # クエリを拡張・強化
  def augment_query(query, context)
    # キーワード抽出
    keywords = extract_keywords(query, context)
    
    # 拡張クエリの生成
    augmented_parts = [query]
    
    # コンテキストから関連情報を追加
    if context[:retrieved_messages]&.any?
      related_contents = context[:retrieved_messages]
                          .take(2)
                          .map { |m| m[:message].content }
      augmented_parts << "関連する過去の問い合わせ: #{related_contents.join(', ')}"
    end
    
    if context[:relevant_solutions]&.any?
      augmented_parts << "推奨される解決策: #{context[:relevant_solutions].join(', ')}"
    end
    
    augmented_query = augmented_parts.join(' ')
    
    # 推奨アプローチの生成
    suggested_approaches = generate_suggested_approaches(context)
    
    {
      original_query: query,
      augmented_query: augmented_query,
      context_used: true,
      keywords: keywords,
      suggested_approaches: suggested_approaches
    }
  end
  
  # RAGベースの応答生成
  def generate_response(query, context, conversation: nil)
    # 応答生成開始
    sources = context[:retrieved_messages]&.map do |msg|
      {
        message_id: msg[:message].id,
        relevance_score: msg[:score]
      }
    end || []
    
    # コンテキストに基づく応答内容の生成
    response_content = build_response_content(query, context)
    
    # 信頼度スコアの計算
    confidence = calculate_confidence(context)
    
    {
      content: response_content,
      sources_used: sources,
      confidence_score: confidence,
      metadata: {
        rag_enabled: true,
        context_count: context[:retrieved_messages]&.size || 0,
        generation_method: 'rag_augmented',
        timestamp: Time.current
      }
    }
  end
  
  # 完全なRAGパイプライン
  def rag_pipeline(query, conversation: nil)
    start_time = Time.current
    
    # 1. コンテキスト取得
    retrieval_start = Time.current
    context = retrieve_context(query, conversation: conversation)
    retrieval_time = (Time.current - retrieval_start) * 1000
    
    # 2. クエリ拡張
    augmentation_start = Time.current
    augmented_query = augment_query(query, context)
    augmentation_time = (Time.current - augmentation_start) * 1000
    
    # 3. 応答生成
    generation_start = Time.current
    response = generate_response(query, context, conversation: conversation)
    generation_time = (Time.current - generation_start) * 1000
    
    total_time = (Time.current - start_time) * 1000
    
    {
      context: context,
      augmented_query: augmented_query,
      response: response,
      performance_metrics: {
        retrieval_time_ms: retrieval_time.round(2),
        augmentation_time_ms: augmentation_time.round(2),
        generation_time_ms: generation_time.round(2),
        total_time_ms: total_time.round(2)
      }
    }
  end
  
  # 関連性評価
  def evaluate_relevance(query, message)
    # クエリとメッセージの類似度を計算
    query_embedding = @vector_service.generate_embedding(query)
    message_embedding = message.embedding || @vector_service.generate_embedding(message.content)
    
    similarity = @semantic_service.calculate_similarity(query_embedding, message_embedding)
    
    # 0-1の範囲に正規化（コサイン類似度は-1から1なので）
    (similarity + 1) / 2
  end
  
  # 日付でフィルタリング
  def filter_by_date(messages, days: nil)
    return messages unless days
    
    cutoff_date = days.days.ago
    
    messages.select do |msg_data|
      msg_data[:message].created_at >= cutoff_date
    end
  end
  
  # 解決策のランク付け
  def rank_solutions(solutions)
    ranked = solutions.map do |solution|
      success_rate = solution[:attempt_count] > 0 ? 
                     solution[:success_count].to_f / solution[:attempt_count] : 0
      
      # ランクスコアの計算（成功率ベース）
      rank_score = success_rate * 100
      
      solution.merge(
        success_rate: success_rate,
        rank_score: rank_score
      )
    end
    
    # スコアで降順ソート
    ranked.sort_by { |s| -s[:rank_score] }
  end
  
  # コンテキストの統合
  def merge_contexts(contexts)
    merged_items = []
    sources = []
    
    contexts.each do |context|
      sources << context[:source]
      merged_items.concat(context[:items])
    end
    
    # 重複除去（同じIDのアイテムを除去）
    unique_items = merged_items.uniq { |item| item.id }
    
    {
      sources: sources.uniq,
      total_items: unique_items.size,
      items: unique_items
    }
  end
  
  # 適応的な取得戦略
  def adaptive_retrieval(query, urgency: nil)
    # クエリの複雑さを判定
    complexity = assess_query_complexity(query)
    
    # 緊急度に基づく調整
    if urgency == 'high'
      retrieval_limit = 10
      threshold = 0.5
    else
      retrieval_limit = 3
      threshold = 0.7
    end
    
    # 複雑なクエリの場合はマルチステージ戦略
    if complexity == :complex
      {
        strategy: 'multi_stage',
        stages: 3,
        retrieval_limit: retrieval_limit,
        threshold: threshold
      }
    else
      {
        strategy: 'single_stage',
        stages: 1,
        retrieval_limit: retrieval_limit,
        threshold: threshold
      }
    end
  end
  
  private
  
  # キャッシュの有効性チェック
  def cached_context_valid?(query, ttl)
    return false unless @cache[query]
    return false unless @cache_timestamps[query]
    
    Time.current - @cache_timestamps[query] < ttl
  end
  
  # 解決策の抽出
  def extract_solutions(messages)
    solutions = []
    
    messages.each do |msg_data|
      message = msg_data[:message]
      
      # メタデータから解決策を抽出
      if message.metadata && message.metadata['resolution']
        solutions << message.metadata['resolution']
      end
    end
    
    solutions.uniq
  end
  
  # コンテキストサマリの生成
  def generate_context_summary(messages, solutions)
    return '関連する過去の情報が見つかりませんでした。' if messages.empty?
    
    summary_parts = []
    
    if messages.any?
      summary_parts << "#{messages.size}件の類似した問い合わせが見つかりました"
    end
    
    if solutions.any?
      summary_parts << "推奨される解決策: #{solutions.take(2).join('、')}"
    end
    
    summary_parts.join('。')
  end
  
  # キーワード抽出
  def extract_keywords(query, context)
    keywords = []
    
    # クエリから基本キーワードを抽出
    base_keywords = query.split(/[、。\s]+/).select { |w| w.length > 1 }
    keywords.concat(base_keywords)
    
    # 特定のキーワードを追加
    keywords << 'ログイン' if query.include?('ログイン')
    keywords << 'パスワード' if query.include?('パスワード')
    
    # コンテキストからもキーワードを抽出
    if context[:retrieved_messages]
      context[:retrieved_messages].each do |msg|
        content = msg[:message].content
        keywords << 'パスワード' if content.include?('パスワード')
        keywords << 'アカウント' if content.include?('アカウント')
      end
    end
    
    keywords.uniq
  end
  
  # 推奨アプローチの生成
  def generate_suggested_approaches(context)
    approaches = []
    
    if context[:relevant_solutions]&.any?
      approaches << "過去の成功事例に基づく解決"
    end
    
    if context[:retrieved_messages]&.any?
      approaches << "類似ケースの参照"
    end
    
    approaches << "段階的なトラブルシューティング" if approaches.empty?
    
    approaches
  end
  
  # 応答内容の構築
  def build_response_content(query, context)
    response_parts = []
    
    # 基本的な応答
    response_parts << "お問い合わせありがとうございます。"
    
    # コンテキストに基づく情報
    if context[:relevant_solutions]&.any?
      response_parts << "以下の解決策をお試しください："
      context[:relevant_solutions].each_with_index do |solution, idx|
        response_parts << "#{idx + 1}. #{solution}"
      end
    elsif context[:retrieved_messages]&.any?
      response_parts << "類似の問題について過去の事例を参考にご案内します。"
    else
      response_parts << "お問い合わせの内容について確認させていただきます。"
    end
    
    response_parts.join("\n")
  end
  
  # 信頼度の計算
  def calculate_confidence(context)
    return 0.1 if context[:retrieved_messages].nil? || context[:retrieved_messages].empty?
    
    # 取得したメッセージの平均スコアを信頼度とする
    scores = context[:retrieved_messages].map { |m| m[:score] }
    scores.sum.to_f / scores.size
  end
  
  # クエリの複雑さ評価
  def assess_query_complexity(query)
    # 簡易的な複雑さ判定
    word_count = query.split(/[、。\s]+/).size
    
    # 複雑さの条件を緩和
    if word_count > 10 || query.include?('かつ') || query.include?('また') || 
       query.include?('失敗') || query.include?('通らない')
      :complex
    else
      :simple
    end
  end
end