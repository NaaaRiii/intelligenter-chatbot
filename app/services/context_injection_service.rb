# frozen_string_literal: true

class ContextInjectionService
  attr_reader :rag_service
  
  def initialize
    @rag_service = RagService.new
  end
  
  # 関連FAQ、事例、製品情報を注入
  def inject_context(query, conversation: nil)
    # 各種情報を並行して取得
    faqs = fetch_relevant_faqs(query)
    case_studies = fetch_case_studies(query).to_a  # to_aで配列に変換
    product_info = fetch_product_info(query)
    
    # 統合コンテキストの生成
    integrated_context = integrate_all_contexts(faqs, case_studies, product_info, query)
    
    {
      faqs: faqs,
      case_studies: case_studies,
      product_info: product_info,
      integrated_context: integrated_context
    }
  end
  
  # 関連FAQの取得
  def fetch_relevant_faqs(query, limit: 3)
    # FAQタイプのナレッジベースを検索
    faqs = KnowledgeBase.where(pattern_type: 'faq')
    
    # クエリとの関連性で絞り込み
    relevant_faqs = filter_by_relevance(faqs, query)
    
    # 優先度順にソート
    sorted_faqs = sort_by_priority(relevant_faqs, query)
    
    # 配列の場合はtakeを使用、ActiveRecord::Relationの場合はlimitを使用
    if sorted_faqs.is_a?(Array)
      sorted_faqs.take(limit)
    else
      sorted_faqs.limit(limit)
    end
  end
  
  # FAQのフォーマット
  def format_faqs(query)
    faqs = fetch_relevant_faqs(query)
    
    faqs.map do |faq|
      {
        question: faq.content['question'],
        answer: faq.content['answer'],
        relevance_score: calculate_relevance_score(query, faq),
        tags: faq.tags || []
      }
    end
  end
  
  # 類似事例の取得
  def fetch_case_studies(query, limit: 3, prioritize_success: false)
    # 問題タイプを推定
    problem_type = infer_problem_type(query)
    
    # 関連する解決パスを取得
    cases = ResolutionPath.where(problem_type: problem_type)
    
    # 成功事例を優先
    if prioritize_success
      cases = cases.where(successful: true)
    end
    
    cases.order(successful: :desc, created_at: :desc).limit(limit)
  end
  
  # 事例の構造化
  def structure_case_studies(query)
    cases = fetch_case_studies(query)
    
    cases.map do |case_study|
      {
        problem_description: case_study.problem_type,
        solution_applied: case_study.solution,
        resolution_steps: case_study.steps_count,
        time_to_resolve: case_study.resolution_time,
        customer_segment: case_study.metadata&.dig('customer_type') || 'general'
      }
    end
  end
  
  # 製品情報の取得
  def fetch_product_info(query)
    # 製品情報タイプのナレッジベースを検索
    products = KnowledgeBase.where(pattern_type: 'product_info')
    
    # クエリとの関連性でフィルタ
    relevant_products = products.select do |product|
      is_relevant_product?(query, product)
    end
    
    relevant_products
  end
  
  # 製品機能の取得
  def get_product_features(query)
    products = fetch_product_info(query)
    
    products.map do |product|
      {
        product_name: product.content['name'],
        relevant_features: extract_relevant_features(query, product),
        documentation_link: product.content['documentation_url'],
        setup_guide: generate_setup_guide(product)
      }
    end
  end
  
  # 製品情報の統合
  def integrate_product_info(query)
    products = fetch_product_info(query)
    
    all_features = []
    doc_links = []
    
    products.each do |product|
      all_features.concat(product.content['features'] || [])
      doc_links << product.content['documentation_url'] if product.content['documentation_url']
    end
    
    {
      products: products.map { |p| p.content['name'] },
      total_features: all_features.uniq.size,
      documentation_links: doc_links.uniq
    }
  end
  
  # エンリッチされたコンテキストの構築
  def build_enriched_context(query, base_context)
    # 各種情報を取得
    faqs = format_faqs(query)
    cases = structure_case_studies(query)
    products = get_product_features(query)
    
    # 情報をランク付け
    ranked_info = rank_information(faqs, cases, products)
    
    # サマリ生成
    summary = generate_context_summary(faqs, cases, products)
    
    {
      sources: ['faq', 'cases', 'products'],
      total_context_items: faqs.size + cases.size + products.size,
      confidence_level: calculate_confidence(faqs, cases, products),
      ranked_information: ranked_info,
      summary: summary
    }
  end
  
  # 情報の優先順位付け
  def prioritize_information(faqs: [], cases: [], products: [], weights: nil)
    weights ||= { faq: 0.35, cases: 0.35, products: 0.3 }
    
    all_items = []
    
    # FAQを追加
    faqs.each do |faq|
      all_items << {
        type: 'faq',
        content: faq,
        priority_score: (faq[:relevance_score] || 0.5) * weights[:faq] * 100
      }
    end
    
    # 事例を追加
    cases.each do |case_item|
      all_items << {
        type: 'case',
        content: case_item,
        priority_score: (case_item[:success_rate] || 0.5) * weights[:cases] * 100
      }
    end
    
    # 製品情報を追加
    products.each do |product|
      all_items << {
        type: 'product',
        content: product,
        priority_score: (product[:relevance] || 0.5) * weights[:products] * 100
      }
    end
    
    # 優先度でソート
    all_items.sort_by { |item| -item[:priority_score] }
  end
  
  # コンテキストを活用した応答生成
  def generate_contextual_response(query, enriched_context)
    # 参照情報の準備
    references = build_references(enriched_context)
    
    # 推奨アクションの生成
    suggested_actions = generate_suggested_actions(enriched_context)
    
    # 解決手順の生成
    resolution_steps = generate_resolution_steps(query, enriched_context)
    
    # 応答内容の生成
    content = build_response_content(query, enriched_context)
    
    {
      content: content,
      references: references,
      suggested_actions: suggested_actions,
      resolution_steps: resolution_steps
    }
  end
  
  # ナレッジベースの更新
  def update_knowledge_base(conversation, resolution_data)
    # 新しいナレッジベースエントリを作成
    kb = KnowledgeBase.create!(
      pattern_type: 'resolution_pattern',
      content: {
        problem: resolution_data[:problem],
        solution: resolution_data[:solution],
        steps: resolution_data[:steps],
        successful: resolution_data[:successful]
      },
      tags: extract_tags(resolution_data),
      success_score: resolution_data[:successful] ? 100 : 0
    )
    
    {
      created: true,
      knowledge_base_id: kb.id,
      pattern_type: kb.pattern_type
    }
  end
  
  # FAQとして保存
  def save_as_faq(faq_data)
    faq = KnowledgeBase.create!(
      pattern_type: 'faq',
      content: {
        question: faq_data[:question],
        answer: faq_data[:answer]
      },
      tags: faq_data[:tags] || [],
      success_score: 50 # デフォルトスコア
    )
    
    {
      created: true,
      faq_id: faq.id
    }
  end
  
  # 類似コンテキストの検索
  def search_similar_contexts(query)
    # 各ソースから検索
    faq_results = search_in_faqs(query)
    case_results = search_in_cases(query)
    product_results = search_in_products(query)
    
    # 結果を統合
    all_results = faq_results + case_results + product_results
    
    # 類似度でソート
    top_matches = all_results.sort_by { |r| -r[:similarity_score] }.take(10)
    
    {
      total_results: all_results.size,
      by_source: {
        'faq' => faq_results.size,
        'cases' => case_results.size,
        'products' => product_results.size
      },
      top_matches: top_matches
    }
  end
  
  # コンテキスト注入の最適化
  def optimize_context_injection(query)
    # クエリの複雑さを評価
    complexity = assess_query_complexity(query)
    
    if complexity == :complex
      {
        injection_depth: 5,
        max_items: 15,
        timeout_ms: 3000,
        parallel_fetch: true
      }
    else
      {
        injection_depth: 3,
        max_items: 8,
        timeout_ms: 2000,
        parallel_fetch: true
      }
    end
  end
  
  # コンテキストの関連性検証
  def validate_context_relevance(query, context_items)
    validated = []
    
    context_items.each do |item|
      relevance = calculate_item_relevance(query, item)
      
      # 関連性が閾値以上のもののみ含める
      if relevance > 0.3
        item[:relevance_score] = relevance
        validated << item
      end
    end
    
    validated
  end
  
  private
  
  # 関連性でフィルタリング
  def filter_by_relevance(items, query)
    # itemsが空の場合は早期リターン
    return items if items.empty?
    
    # 日本語の場合も考慮してクエリを分割
    query_words = query.downcase.split(/[\s　]+/)  # 全角スペースも考慮
    
    # 主要なキーワードを抽出（「できない」「できません」などを除去）
    base_words = query_words.map do |word|
      word.gsub(/できない|できません|ない|ません/, '')
    end.reject(&:empty?)
    
    # クエリワードと基本ワードを両方使用
    all_words = (query_words + base_words).uniq
    
    filtered = items.select do |item|
      # contentがHashの場合とStringの場合に対応
      content_text = if item.content.is_a?(Hash)
                       item.content.values.flatten.join(' ').downcase
                     else
                       item.content.to_s.downcase
                     end
      
      # タグも検索対象に含める
      tag_text = item.tags&.join(' ').to_s.downcase
      full_text = "#{content_text} #{tag_text}"
      
      # より緩い条件でマッチング
      matched = all_words.any? { |word| 
        word.length > 1 && full_text.include?(word)
      }
      
      # 特定のキーワードマッチング
      if query.include?('ログイン')
        matched ||= full_text.include?('ログイン') || full_text.include?('login') || 
                   full_text.include?('パスワード') || full_text.include?('認証')
      end
      
      if query.include?('パスワード')
        matched ||= full_text.include?('パスワード') || full_text.include?('password') ||
                   full_text.include?('リセット') || full_text.include?('reset')
      end
      
      matched
    end
    
    # ActiveRecord::Relationか配列かを維持
    items.is_a?(ActiveRecord::Relation) ? items.where(id: filtered.map(&:id)) : filtered
  end
  
  # 優先度でソート
  def sort_by_priority(items, query)
    items.sort_by do |item|
      -calculate_relevance_score(query, item)
    end
  end
  
  # 関連性スコアの計算
  def calculate_relevance_score(query, item)
    # 簡易的な実装
    query_words = query.downcase.split(/\s+/)
    
    # contentがHashの場合とStringの場合に対応
    content_text = if item.content.is_a?(Hash)
                     item.content.values.flatten.join(' ').downcase
                   else
                     item.content.to_s.downcase
                   end
    
    # タグも考慮
    tag_text = item.tags&.join(' ').to_s.downcase
    full_text = "#{content_text} #{tag_text}"
    
    matches = query_words.count { |word| full_text.include?(word) }
    matches.to_f / query_words.size
  end
  
  # 問題タイプの推定
  def infer_problem_type(query)
    if query.include?('ログイン') || query.include?('パスワード')
      'login_issue'
    elsif query.include?('支払い') || query.include?('決済')
      'payment_issue'
    elsif query.include?('エラー')
      'error_issue'
    else
      'general_issue'
    end
  end
  
  # 製品の関連性チェック
  def is_relevant_product?(query, product)
    return false unless product.content
    
    product_text = "#{product.content['name']} #{product.content['features']&.join(' ')}"
    tag_text = product.tags&.join(' ').to_s
    full_text = "#{product_text} #{tag_text}"
    
    query_words = query.downcase.split(/\s+/)
    
    # クエリの単語が製品情報に含まれているか、または関連キーワードがあるか
    has_match = query_words.any? { |word| 
      word.length > 1 && full_text.downcase.include?(word)
    }
    
    # 特定のキーワードでのマッチングも考慮
    if query.include?('認証') || query.include?('ログイン') || query.include?('エラー')
      has_match ||= product_text.downcase.include?('auth') || 
                    product_text.downcase.include?('認証') ||
                    product_text.downcase.include?('sso') ||
                    tag_text.downcase.include?('authentication')
    end
    
    if query.include?('SSO') || query.include?('sso')
      has_match ||= product_text.include?('SSO') || 
                    product.content['features']&.any? { |f| f.include?('SSO') }
    end
    
    if query.include?('システム') || query.include?('全般')
      has_match ||= product_text.include?('システム') || tag_text.include?('system')
    end
    
    has_match
  end
  
  # 関連機能の抽出
  def extract_relevant_features(query, product)
    return [] unless product.content['features']
    
    product.content['features'].select do |feature|
      query.downcase.split(/\s+/).any? { |word| feature.downcase.include?(word) }
    end
  end
  
  # セットアップガイドの生成
  def generate_setup_guide(product)
    "#{product.content['name']}のセットアップガイドをご確認ください。"
  end
  
  # 全コンテキストの統合
  def integrate_all_contexts(faqs, cases, products, query)
    context_parts = []
    
    # 配列やActiveRecord::Relationの要素数を取得
    faq_count = faqs.respond_to?(:size) ? faqs.size : 0
    case_count = cases.respond_to?(:size) ? cases.size : 0
    product_count = products.respond_to?(:size) ? products.size : 0
    
    if faq_count > 0
      context_parts << "FAQ: #{faq_count}件の関連情報"
    end
    
    if case_count > 0
      context_parts << "事例: #{case_count}件の類似ケース"
    end
    
    if product_count > 0
      context_parts << "製品: #{product_count}件の関連製品"
    end
    
    context_parts.any? ? context_parts.join('、') : '関連情報を検索中'
  end
  
  # 情報のランク付け
  def rank_information(faqs, cases, products)
    all_info = []
    
    faqs.each { |f| all_info << { type: 'faq', data: f, importance: f[:relevance_score] || 0.5 } }
    cases.each { |c| all_info << { type: 'case', data: c, importance: 0.7 } }
    products.each { |p| all_info << { type: 'product', data: p, importance: 0.6 } }
    
    all_info.sort_by { |i| -i[:importance] }
  end
  
  # コンテキストサマリの生成
  def generate_context_summary(faqs, cases, products)
    summary_parts = []
    
    summary_parts << "FAQ#{faqs.size}件" if faqs.any?
    summary_parts << "事例#{cases.size}件" if cases.any?
    summary_parts << "製品情報#{products.size}件" if products.any?
    
    "以下の情報を参照しています: #{summary_parts.join('、')}"
  end
  
  # 信頼度の計算
  def calculate_confidence(faqs, cases, products)
    total_items = faqs.size + cases.size + products.size
    return 0.1 if total_items == 0
    
    # アイテム数に基づく信頼度（最大0.9）
    [0.9, total_items * 0.15].min
  end
  
  # 参照情報の構築
  def build_references(enriched_context)
    refs = []
    
    if enriched_context[:faqs]
      enriched_context[:faqs].each do |faq|
        refs << { type: 'faq', content: faq[:question], link: nil }
      end
    end
    
    if enriched_context[:cases]
      enriched_context[:cases].each do |case_item|
        refs << { type: 'case', content: case_item[:solution], link: nil }
      end
    end
    
    if enriched_context[:products]
      enriched_context[:products].each do |product|
        refs << { type: 'product', content: product[:name], link: product[:documentation_url] }
      end
    end
    
    refs
  end
  
  # 推奨アクションの生成
  def generate_suggested_actions(enriched_context)
    actions = []
    
    if enriched_context[:faqs]&.any?
      actions << 'FAQを確認する'
    end
    
    if enriched_context[:cases]&.any?
      actions << '類似事例を参考にする'
    end
    
    if enriched_context[:products]&.any?
      actions << '製品ドキュメントを参照する'
    end
    
    actions
  end
  
  # 解決手順の生成
  def generate_resolution_steps(query, enriched_context)
    steps = []
    
    steps << {
      step_number: 1,
      action: '問題の詳細を確認',
      expected_result: '問題の原因を特定'
    }
    
    if enriched_context[:cases]&.any?
      steps << {
        step_number: 2,
        action: '類似事例の解決策を試す',
        expected_result: '問題が解決される'
      }
    end
    
    steps << {
      step_number: steps.size + 1,
      action: 'サポートに連絡',
      expected_result: '専門的なサポートを受ける'
    }
    
    steps
  end
  
  # 応答内容の構築
  def build_response_content(query, enriched_context)
    content_parts = []
    
    content_parts << "「#{query}」についてお答えします。"
    
    if enriched_context[:faqs]&.any?
      content_parts << "よくある質問を確認しました。"
    end
    
    if enriched_context[:cases]&.any?
      content_parts << "類似の事例が見つかりました。"
    end
    
    if enriched_context[:products]&.any?
      content_parts << "関連する製品情報があります。"
    end
    
    content_parts.join("\n")
  end
  
  # タグの抽出
  def extract_tags(resolution_data)
    tags = []
    
    tags << 'successful' if resolution_data[:successful]
    tags << resolution_data[:problem].downcase.split(/\s+/).first if resolution_data[:problem]
    
    tags
  end
  
  # FAQでの検索
  def search_in_faqs(query)
    faqs = KnowledgeBase.where(pattern_type: 'faq')
    
    faqs.map do |faq|
      {
        type: 'faq',
        content: faq.content,
        similarity_score: calculate_relevance_score(query, faq)
      }
    end
  end
  
  # 事例での検索
  def search_in_cases(query)
    problem_type = infer_problem_type(query)
    cases = ResolutionPath.where(problem_type: problem_type)
    
    cases.map do |case_item|
      {
        type: 'case',
        content: { solution: case_item.solution },
        similarity_score: 0.7 # 簡易実装
      }
    end
  end
  
  # 製品情報での検索
  def search_in_products(query)
    products = KnowledgeBase.where(pattern_type: 'product_info')
    
    products.map do |product|
      {
        type: 'product',
        content: product.content,
        similarity_score: is_relevant_product?(query, product) ? 0.6 : 0.1
      }
    end
  end
  
  # クエリの複雑さ評価
  def assess_query_complexity(query)
    word_count = query.split(/\s+/).size
    
    if word_count > 10 || query.include?('複雑') || query.include?('複数')
      :complex
    else
      :simple
    end
  end
  
  # アイテムの関連性計算
  def calculate_item_relevance(query, item)
    content_text = item[:content].to_s.downcase
    query_words = query.downcase.split(/\s+/)
    
    matches = query_words.count { |word| content_text.include?(word) }
    matches.to_f / query_words.size
  end
end