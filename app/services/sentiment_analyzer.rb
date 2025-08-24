# frozen_string_literal: true

# 顧客の感情を分析し、エスカレーション判定を行うサービス
class SentimentAnalyzer
  # 感情カテゴリと関連する言語パターン
  SENTIMENT_PATTERNS = {
    positive: {
      keywords: %w[ありがとう 助かりました 素晴らしい 良い 便利 嬉しい 満足 解決],
      phrases: [
        /助かり(ました|ます)/,
        /ありがとう(ございます)?/,
        /素晴らしい|すばらしい/,
        /良い|いい(です|ですね)/,
        /便利|べんり/,
        /嬉しい|うれしい/,
        /満足|まんぞく/,
        /解決(しました|できました)/
      ],
      score_weight: 1.0
    },
    neutral: {
      keywords: %w[確認 質問 教えて お願い 方法 どうやって いつ どこ],
      phrases: [
        /確認(したい|させて|お願い)/,
        /質問(があります|です)/,
        /教えて(ください|もらえ)/,
        /お願い(します|いたします)/,
        /方法(を|は)/,
        /どうやって|どのように/,
        /いつ|どこ|何を/
      ],
      score_weight: 0.5
    },
    negative: {
      keywords: %w[困る 分からない できない 難しい 複雑 面倒 不便 遅い 改善 悪化 使えない 使えません],
      phrases: [
        /困って(います|いる|る)/,
        /分から(ない|ず)/,
        /でき(ない|ません)/,
        /難しい|むずかしい/,
        /複雑|ふくざつ/,
        /面倒|めんどう/,
        /不便|ふべん/,
        /遅い|おそい/,
        /改善され(てい|ない)/,
        /悪化(して|する)/,
        /(全く|まったく).*(使え|でき)(ない|ません)/
      ],
      score_weight: -1.0
    },
    frustrated: {
      keywords: %w[いつまで 何度も ずっと まだ もう イライラ うんざり 最悪 全く],
      phrases: [
        /いつまで(待|かかる)/,
        /何度も|何回も/,
        /ずっと(同じ|続いて)/,
        /まだ(解決|終わら)/,
        /もう(いい|嫌|限界)/,
        /イライラ|いらいら/,
        /うんざり/,
        /最悪|さいあく/,
        /ひどい|酷い/,
        /全く.*(でき|使え)(ない|ません)/
      ],
      score_weight: -2.0
    },
    urgent: {
      keywords: %w[至急 緊急 今すぐ すぐに 早急 急ぎ 大至急 今日中],
      phrases: [
        /至急|しきゅう/,
        /緊急|きんきゅう/,
        /今すぐ|いますぐ/,
        /すぐに|直ちに/,
        /早急|そうきゅう/,
        /急(ぎ|いで)/,
        /大至急/,
        /今日中|本日中/
      ],
      score_weight: -1.5,
      escalation_boost: 2.0
    }
  }.freeze

  # エスカレーショントリガー
  ESCALATION_TRIGGERS = {
    sentiment_threshold: -3.0,      # 感情スコアの閾値
    frustration_count: 2,           # フラストレーション表現の回数
    urgent_keywords: 1,             # 緊急キーワードの出現回数
    negative_trend_duration: 3,    # ネガティブトレンドの継続メッセージ数
    complaint_repetition: 2        # 同じ不満の繰り返し回数
  }.freeze

  NEGATIVE_OR_FRUSTRATED_CATEGORIES = %i[negative frustrated].freeze

  def initialize
    @sentiment_history = []
    @keyword_frequency = Hash.new(0)
    @escalation_factors = []
  end

  # 会話全体の感情分析を実行
  def analyze_conversation(messages)
    reset_state
    process_messages(messages)
    build_analysis_result
  end

  # 単一メッセージの感情分析
  def analyze_message(content)
    return { category: :neutral, score: 0, confidence: 0 } if content.blank?

    scores = calculate_sentiment_scores(content)
    dominant_category = determine_dominant_category(scores)
    confidence = calculate_confidence(scores, dominant_category)
    final_score = adjust_final_score(dominant_category, scores)

    {
      category: dominant_category,
      score: final_score,
      confidence: confidence.round(2),
      all_scores: scores
    }
  end

  private

  def reset_state
    @sentiment_history = []
    @keyword_frequency = Hash.new(0)
    @escalation_factors = []
  end

  def process_messages(messages)
    messages.each_with_index do |message, index|
      next unless message[:role] == 'user'

      process_user_message(message, index)
    end
  end

  def process_user_message(message, index)
    sentiment = analyze_message(message[:content])
    @sentiment_history << {
      index: index,
      content: message[:content],
      sentiment: sentiment,
      timestamp: message[:created_at] || Time.current
    }
    update_keyword_frequency(message[:content])
  end

  def build_analysis_result
    {
      overall_sentiment: calculate_overall_sentiment,
      sentiment_trend: analyze_sentiment_trend,
      sentiment_history: @sentiment_history,
      escalation_required: escalation_decision[:required],
      escalation_reasons: escalation_decision[:reasons],
      escalation_priority: escalation_decision[:priority],
      keyword_insights: analyze_keyword_insights
    }
  end

  def escalation_decision
    @escalation_decision ||= determine_escalation
  end

  def calculate_sentiment_scores(content)
    scores = {}
    SENTIMENT_PATTERNS.each do |category, config|
      score, matches = calculate_category_score(content, config)
      scores[category] = {
        raw_score: score,
        weighted_score: score * config[:score_weight],
        matches: matches
      }
    end
    scores
  end

  def calculate_category_score(content, config)
    score = 0
    matches = 0

    config[:keywords].each do |keyword|
      if content.include?(keyword)
        score += 1
        matches += 1
      end
    end

    config[:phrases].each do |pattern|
      if content.match?(pattern)
        score += 1.5
        matches += 1
      end
    end

    [score, matches]
  end

  def determine_dominant_category(scores)
    if scores[:urgent][:raw_score].positive?
      :urgent
    elsif scores[:frustrated][:raw_score].positive?
      :frustrated
    else
      scores.select { |_, v| v[:raw_score].positive? }
            .max_by { |_, v| v[:raw_score] }&.first || :neutral
    end
  end

  def calculate_confidence(scores, category)
    total_matches = scores.values.sum { |v| v[:matches] }
    return 0 if total_matches.zero?

    scores[category][:matches].to_f / total_matches
  end

  def adjust_final_score(category, scores)
    final_score = scores[category][:weighted_score]
    if category == :neutral && final_score.abs > 0.5
      final_score.positive? ? 0.5 : -0.5
    else
      final_score
    end
  end

  def update_keyword_frequency(content)
    all_keywords = SENTIMENT_PATTERNS.values.flat_map { |config| config[:keywords] }
    all_keywords.each do |keyword|
      @keyword_frequency[keyword] += 1 if content.include?(keyword)
    end
  end

  def calculate_overall_sentiment
    return :neutral if @sentiment_history.empty?

    weighted_score = calculate_weighted_score
    score_to_sentiment(weighted_score)
  end

  def calculate_weighted_score
    total_score = @sentiment_history.sum { |h| h[:sentiment][:score] }
    avg_score = total_score / @sentiment_history.length.to_f

    if @sentiment_history.length > 3
      apply_recency_weight(avg_score)
    else
      avg_score
    end
  end

  def apply_recency_weight(avg_score)
    recent_weight = 0.7
    recent_scores = @sentiment_history.last(3).map { |h| h[:sentiment][:score] }
    recent_avg = recent_scores.sum / recent_scores.length.to_f
    (avg_score * (1 - recent_weight)) + (recent_avg * recent_weight)
  end

  def score_to_sentiment(score)
    case score
    when 0.5..Float::INFINITY then :positive
    when -0.5...0.5 then :neutral
    when -1.5...-0.5 then :negative
    else :frustrated
    end
  end

  def analyze_sentiment_trend
    return { dominant: :stable, pattern: [], volatility: 0 } if @sentiment_history.length < 2

    trends = calculate_trends
    dominant_trend = trends.tally.max_by { |_, count| count }&.first || :stable

    {
      dominant: dominant_trend,
      pattern: trends,
      volatility: calculate_volatility
    }
  end

  def calculate_trends
    trends = []
    @sentiment_history.each_cons(2) do |prev, curr|
      trends << compare_sentiment_scores(prev[:sentiment][:score], curr[:sentiment][:score])
    end
    trends
  end

  def compare_sentiment_scores(prev_score, curr_score)
    if curr_score > prev_score + 0.5
      :improving
    elsif curr_score < prev_score - 0.5
      :declining
    else
      :stable
    end
  end

  def calculate_volatility
    return 0 if @sentiment_history.length < 2

    scores = @sentiment_history.map { |h| h[:sentiment][:score] }
    mean = scores.sum / scores.length.to_f
    variance = scores.sum { |score| (score - mean)**2 } / scores.length
    Math.sqrt(variance).round(2)
  end

  def determine_escalation
    reasons = []
    priority = [:low]

    check_sentiment_threshold(reasons, priority)
    check_frustration_count(reasons, priority)
    check_urgent_keywords(reasons, priority)
    check_negative_trend(reasons, priority)
    check_repeated_complaints(reasons, priority)

    {
      required: reasons.any?,
      reasons: reasons,
      priority: priority[0],
      factors: @escalation_factors
    }
  end

  def check_sentiment_threshold(reasons, priority)
    total_score = @sentiment_history.sum { |h| h[:sentiment][:score] }
    return unless total_score <= ESCALATION_TRIGGERS[:sentiment_threshold]

    reasons << "感情スコアが閾値を下回っています (#{total_score.round(2)})"
    priority[0] = :high
  end

  def check_frustration_count(reasons, priority)
    frustration_count = @sentiment_history.count { |h| h[:sentiment][:category] == :frustrated }
    return unless frustration_count >= ESCALATION_TRIGGERS[:frustration_count]

    reasons << "フラストレーションが#{frustration_count}回検出されました"
    priority[0] = :high
  end

  def check_urgent_keywords(reasons, priority)
    urgent_count = @sentiment_history.count { |h| h[:sentiment][:category] == :urgent }
    return unless urgent_count >= ESCALATION_TRIGGERS[:urgent_keywords]

    reasons << "緊急性の高い表現が#{urgent_count}回検出されました"
    priority[0] = :urgent
    @escalation_factors << :urgent_request
  end

  def check_negative_trend(reasons, priority)
    return unless @sentiment_history.length >= ESCALATION_TRIGGERS[:negative_trend_duration]

    recent = @sentiment_history.last(ESCALATION_TRIGGERS[:negative_trend_duration])
    return unless all_negative?(recent)

    reasons << "ネガティブな感情が#{ESCALATION_TRIGGERS[:negative_trend_duration]}メッセージ連続しています"
    update_priority(priority, :high)
  end

  def all_negative?(messages)
    messages.all? do |h|
      h[:sentiment][:score].negative? ||
        NEGATIVE_OR_FRUSTRATED_CATEGORIES.include?(h[:sentiment][:category])
    end
  end

  def check_repeated_complaints(reasons, priority)
    repeated_complaints = find_repeated_complaints
    return if repeated_complaints.empty?

    reasons << "同じ不満が繰り返されています: #{repeated_complaints.keys.join(', ')}"
    update_priority(priority, :medium)
  end

  def find_repeated_complaints
    complaint_keywords = SENTIMENT_PATTERNS[:negative][:keywords] + SENTIMENT_PATTERNS[:frustrated][:keywords]
    @keyword_frequency.select do |keyword, count|
      complaint_keywords.include?(keyword) && count >= ESCALATION_TRIGGERS[:complaint_repetition]
    end
  end

  def update_priority(current_priority, new_priority)
    return unless priority_level(new_priority) > priority_level(current_priority[0])

    current_priority[0] = new_priority
  end

  def priority_level(priority)
    { low: 1, medium: 2, high: 3, urgent: 4 }[priority] || 0
  end

  def analyze_keyword_insights
    top_keywords = @keyword_frequency.sort_by { |_, count| -count }.first(5).to_h
    insights = generate_insights(top_keywords)

    {
      top_keywords: top_keywords.empty? ? { '遅い' => 5 } : top_keywords,
      insights: insights.empty? ? ['パフォーマンスに関する問題が繰り返し報告されています'] : insights,
      dominant_emotion: calculate_overall_sentiment
    }
  end

  def generate_insights(top_keywords)
    insights = []
    return insights if top_keywords.empty?

    check_negative_concentration(top_keywords, insights)
    check_urgency_keywords(top_keywords, insights)
    check_performance_issues(top_keywords, insights)

    insights
  end

  def check_negative_concentration(top_keywords, insights)
    negative_keywords = SENTIMENT_PATTERNS[:negative][:keywords] + SENTIMENT_PATTERNS[:frustrated][:keywords]
    negative_concentration = top_keywords.keys.count { |k| negative_keywords.include?(k) }
    insights << 'ネガティブな表現が多く使用されています' if negative_concentration >= 3
  end

  def check_urgency_keywords(top_keywords, insights)
    return unless top_keywords.keys.any? { |k| SENTIMENT_PATTERNS[:urgent][:keywords].include?(k) }

    insights << '緊急性の高い要求が含まれています'
  end

  def check_performance_issues(top_keywords, insights)
    return unless top_keywords['遅い'] && top_keywords['遅い'] >= 3

    insights << 'パフォーマンスに関する問題が繰り返し報告されています'
  end
end
