# frozen_string_literal: true

# 会話から顧客ニーズを軽量推定するサービス
# - 初回は簡易（直近1-2件）
# - 閾値到達時に直近5-8件で再推定
class NeedInferenceService
  DEFAULT_VOCAB = {
    'cost' => %w[費用 価格 予算 コスト 見積 料金 値段 単価],
    'timeline' => %w[期間 納期 スケジュール いつ 期限 タイムライン 納入],
    'integration' => %w[連携 API 連動 接続 インテグレーション データ連携],
    'security' => %w[セキュリティ 暗号 化 情報保護 認証 認可 監査],
    'performance' => %w[速度 パフォーマンス 遅い 早い 最適化 レイテンシ スループット],
    'support' => %w[サポート 体制 導入 運用 保守 相談 問い合わせ],
    'marketing' => %w[マーケティング リード獲得 反響 施策 配信 CVR コンバージョン リターゲティング 広告 クリエイティブ],
    'ui_ux' => %w[UI UX デザイン 画面 設計 使いやすさ ナビゲーション ワイヤーフレーム 可用性],
    'analytics' => %w[分析 指標 KPI ダッシュボード レポート 可視化 トラッキング ABテスト],
    'development' => %w[要件 設計 実装 テスト デプロイ CI CD バージョン API 設計書],
    'general' => %w[目的 課題 改善 目標 検討 比較 情報収集]
  }.freeze

  STOPWORDS = %w[
    です ます する した して の に は が を と も で から まで より また など そして しかし ただし ください でしょう ますか ですか
    はい いいえ ありがとう ございます お願い いただき いただけ いただける 可能性 可能 くださいませ お手数 恐れ入ります 承知 了解
    弊社 当社 御社 貴社 ご要望 ご相談 お問い合わせ ご連絡 こちら そちら あちら こと もの ため ので よう にて について 等 等々 など
  ].freeze

  KEYWORD_WHITELIST = %w[
    マーケティング リターゲティング ナビゲーション UI設計 UX改善 分析基盤 データ連携 カスタマージャーニー レポート自動化 コンバージョン ABテスト
  ].freeze

  COMPOUND_PATTERNS = %w[
    マーケティング活動 リターゲティング UI設計 ナビゲーション レポート自動化 データ連携 顧客分析 施策設計 画面設計 指標設計 ダッシュボード設計
  ].freeze

  def initialize(embedding_service: OpenaiEmbeddingService.new, analyzer: InquiryAnalyzerService.new)
    @embedding_service = embedding_service
    @analyzer = analyzer
  end

  # messages: [{role:, content:}]
  def infer(messages: [])
    text = normalize_text(build_corpus(messages))
    keywords = extract_keywords(text)
    if low_quality_keywords?(keywords)
      refined = refine_keywords_via_llm(text)
      keywords = (refined + keywords).uniq.take(8) unless refined.empty?
    end
    similarity = compute_similarity(text)
    category = infer_category(messages, keywords, similarity)
    need_type = infer_need_type(keywords)

    confidence = compute_confidence(similarity, category, need_type)

    {
      'need_type' => need_type,
      'pain_point' => extract_pain_point(messages),
      'desired_outcome' => nil,
      'constraints' => { 'budget' => nil, 'timeline' => nil },
      'category' => category,
      'keywords' => keywords,
      'similarity' => similarity, # [{keyword, score, cluster}]
      'confidence' => confidence,
      'evidence' => evidence_quotes(messages)
    }
  rescue StandardError => e
    Rails.logger.error "NeedInferenceService error: #{e.message}"
    {
      'need_type' => 'general',
      'pain_point' => extract_pain_point(messages),
      'desired_outcome' => nil,
      'constraints' => { 'budget' => nil, 'timeline' => nil },
      'category' => 'general',
      'keywords' => extract_keywords(text || ''),
      'similarity' => [],
      'confidence' => 0.3,
      'evidence' => evidence_quotes(messages)
    }
  end

  private

  def build_corpus(messages)
    messages.map { |m| m[:content].to_s }.join("\n")[0, 4000]
  end

  def normalize_text(text)
    # Unicode正規化と不要文字の除去
    t = text.to_s
    t = t.unicode_normalize(:nfkc) if t.respond_to?(:unicode_normalize)
    # URL/メール/記号の除去
    t = t.gsub(%r{https?://\S+}, ' ')
         .gsub(/[\w.+-]+@[\w.-]+\.[a-zA-Z]{2,}/, ' ')
         .gsub(/[\u200B-\u200D\uFEFF]/, ' ')
    # よくある定型・冗長表現の除去
    generic = /(御社|弊社|貴社|ご要望|ご相談|お問い合わせ|ご連絡|よろしくお願いいたします|よろしくお願いします|はい|いいえ)/
    t = t.gsub(generic, ' ')
    t.squeeze(' ').strip
  end

  def extract_keywords(text)
    # 単純分割 + 日本語向けフィルタ
    raw = text.gsub(/[\s\t\n\r]/, ' ').split(/[^\p{Hiragana}\p{Katakana}\p{Han}\w]+/)
    raw = raw.map(&:strip).reject(&:empty?)

    # ノイズ除去: 短いカタカナ断片や一般語の排除
    filtered = raw.select do |w|
      next false if w.size < 2
      # カタカナ断片（2文字以下）は除外
      next false if w.match?(/^[\p{Katakana}ー]{1,3}$/)
      # ひらがなの短語（3文字以下）は除外
      next false if w.match?(/^[\p{Hiragana}]+$/) && w.size <= 3
      # 一般的な助詞・敬語・定型表現
      next false if STOPWORDS.include?(w)
      true
    end

    # 頻度集計
    freq = Hash.new(0)
    filtered.each { |w| freq[w] += 1 }

    # ホワイトリスト/複合パターンが本文に含まれていれば強制的に加点
    KEYWORD_WHITELIST.each do |kw|
      if text.include?(kw)
        freq[kw] += 2
      end
    end
    COMPOUND_PATTERNS.each do |ph|
      if text.include?(ph)
        freq[ph] += 3
      end
    end

    # サブストリングの除外（長い語を優先）
    sorted = freq.keys.sort_by { |w| -w.length }
    unique = []
    sorted.each do |w|
      unique << w unless unique.any? { |u| u.include?(w) && u != w }
    end

    # 複合パターンを優先し、サブストリングを除外
    prioritized = (COMPOUND_PATTERNS & unique) + (unique - COMPOUND_PATTERNS)
    candidates = []
    prioritized.each do |w|
      next if candidates.any? { |u| u.include?(w) && u != w }
      candidates << w
    end

    candidates.sort_by { |w| -freq[w] }.take(8)
  end

  def compute_similarity(text)
    base = @embedding_service.generate_embedding(text)
    results = []
    DEFAULT_VOCAB.each do |cluster, terms|
      terms.first(5).each do |term|
        score = cosine(base, @embedding_service.generate_embedding(term))
        results << { 'keyword' => term, 'score' => score.round(3), 'cluster' => cluster }
      end
    end
    results.sort_by { |r| -r['score'] }.take(10)
  rescue StandardError => e
    Rails.logger.warn "Similarity calc failed: #{e.message}"
    []
  end

  def infer_category(messages, keywords, similarity)
    last_user = messages.reverse.find { |m| m[:role].to_s == 'user' }
    analysis = @analyzer.analyze(last_user&.dig(:content), messages) rescue nil
    category = analysis&.dig(:category) || analysis&.dig('category')
    return category if category.present?

    # 明示ルール（テキストベースの簡易判定）
    corpus = (messages.map { |m| m[:content].to_s }.join("\n") rescue '')
    return 'ui_ux' if corpus.match?(/UI|UX|ナビゲーション|画面|デザイン|ワイヤ/) || (keywords & DEFAULT_VOCAB['ui_ux']).any?
    return 'marketing' if corpus.match?(/マーケ|CVR|リタ.?ゲ/) || (keywords & DEFAULT_VOCAB['marketing']).any?
    return 'analytics' if corpus.match?(/KPI|ダッシュボード|レポート|分析|可視化/) || (keywords & DEFAULT_VOCAB['analytics']).any?
    return 'development' if corpus.match?(/要件|実装|API|設計|テスト|CI|CD/) || (keywords & DEFAULT_VOCAB['development']).any?

    # キーワードと語彙クラスタの一致数で優先推定
    cluster_counts = {}
    DEFAULT_VOCAB.each do |cluster, terms|
      next if cluster == 'general'
      cluster_counts[cluster] = (keywords & terms).size
    end
    best_cluster, best_count = cluster_counts.max_by { |_, c| c } || [nil, 0]
    return best_cluster if best_count.to_i > 0

    # 類似度のトップクラスタでフォールバック
    top_cluster = similarity.first&.dig('cluster')
    top_cluster || 'general'
  end

  def low_quality_keywords?(keywords)
    return true if keywords.nil? || keywords.empty?
    strong = keywords.select { |w| w.to_s.length >= 3 && !STOPWORDS.include?(w) && w.match?(/[一-龥ぁ-んァ-ヶーA-Za-z]/) }
    strong.size < 3
  end

  def refine_keywords_via_llm(text)
    return [] unless defined?(EnhancedClaudeApiService)
    prompt = <<~PROMPT
      次のテキストから、業務に役立つ具体的なキーフレーズを3〜5個だけ抽出してください。出力は箇条書きのプレーンテキストで、各行1フレーズ、余計な説明なし。
      ---
      #{text}
    PROMPT
    begin
      service = EnhancedClaudeApiService.new
      resp = service.generate_text(prompt: prompt)
      lines = resp.to_s.split("\n").map { |l| l.gsub(/^[-・\*\s]+/, '').strip }.reject(&:empty?)
      # ノイズ除去を再適用
      lines.select { |w| w.length >= 3 && !STOPWORDS.include?(w) }.take(5)
    rescue => e
      Rails.logger.warn "LLM refine failed: #{e.message}"
      []
    end
  end

  def infer_need_type(keywords)
    return 'cost' if (keywords & DEFAULT_VOCAB['cost']).any?
    return 'timeline' if (keywords & DEFAULT_VOCAB['timeline']).any?
    return 'integration' if (keywords & DEFAULT_VOCAB['integration']).any?
    return 'security' if (keywords & DEFAULT_VOCAB['security']).any?
    return 'marketing' if (keywords & DEFAULT_VOCAB['marketing']).any?
    return 'ui_ux' if (keywords & DEFAULT_VOCAB['ui_ux']).any?
    return 'analytics' if (keywords & DEFAULT_VOCAB['analytics']).any?
    return 'development' if (keywords & DEFAULT_VOCAB['development']).any?
    'general'
  end

  def compute_confidence(similarity, category, need_type)
    flags = Rails.configuration.x.needs_preview
    w_sim = flags[:similarity_weight] || 0.4
    w_cat = flags[:category_weight] || 0.2
    # 予約: w_llm = flags[:llm_weight] || 0.4

    sim = similarity.first&.dig('score').to_f # 0..1 近似
    cat_score = (category == need_type || category != 'general') ? 1.0 : 0.0
    ((sim * w_sim) + (cat_score * w_cat)).clamp(0.0, 1.0)
  end

  def evidence_quotes(messages)
    last_user = messages.reverse.find { |m| m[:role].to_s == 'user' }
    [last_user&.dig(:content)].compact
  end

  def extract_pain_point(messages)
    last_user = messages.reverse.find { |m| m[:role].to_s == 'user' }
    last_user&.dig(:content)
  end

  def cosine(a, b)
    return 0.0 if a.nil? || b.nil? || a.empty? || b.empty?
    dot = 0.0
    a.each_with_index { |v, i| dot += v.to_f * b[i].to_f }
    mag_a = Math.sqrt(a.sum { |v| v.to_f * v.to_f })
    mag_b = Math.sqrt(b.sum { |v| v.to_f * v.to_f })
    return 0.0 if mag_a.zero? || mag_b.zero?
    dot / (mag_a * mag_b)
  end
end


