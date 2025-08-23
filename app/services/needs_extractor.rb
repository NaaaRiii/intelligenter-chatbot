# frozen_string_literal: true

# 会話から隠れたニーズを抽出するアルゴリズムサービス
class NeedsExtractor
  # ニーズパターンの定義
  NEED_PATTERNS = {
    efficiency: {
      keywords: %w[遅い 時間がかかる 効率 自動化 短縮 スピード パフォーマンス 改善],
      patterns: [
        /(.{0,20})(遅|重|時間|手間|面倒)(.{0,20})/,
        /(.{0,20})(効率|自動|簡単|楽に)(.{0,20})/,
        /(.{0,20})(速く|早く|短時間)(.{0,20})/
      ],
      suggestion_template: '%sの効率化・自動化ツールの導入'
    },
    cost_reduction: {
      keywords: %w[高い 費用 コスト 予算 料金 価格 節約 削減],
      patterns: [
        /(.{0,20})(高い|高額|費用|コスト)(.{0,20})/,
        /(.{0,20})(予算|料金|価格)(.{0,20})/,
        /(.{0,20})(安く|節約|削減)(.{0,20})/
      ],
      suggestion_template: 'コスト最適化プランの提案'
    },
    feature_request: {
      keywords: %w[できない 機能 追加 改善 欲しい 必要 要望],
      patterns: [
        /(.{0,20})(できない|できません|不可能)(.{0,20})/,
        /(.{0,20})(機能|フィーチャー|feature)(.{0,20})/,
        /(.{0,20})(欲しい|必要|要望|希望)(.{0,20})/
      ],
      suggestion_template: '機能追加・カスタマイズの検討'
    },
    integration: {
      keywords: %w[連携 統合 接続 API 連動 同期 インテグレーション],
      patterns: [
        /(.{0,20})(連携|統合|接続)(.{0,20})/,
        /(.{0,20})(API|インテグレーション|integration)(.{0,20})/,
        /(.{0,20})(同期|連動|つなぐ)(.{0,20})/
      ],
      suggestion_template: '外部システムとの連携強化'
    },
    scalability: {
      keywords: %w[増える 拡大 成長 スケール 大量 多い 増加],
      patterns: [
        /(.{0,20})(増える|増えて|増加)(.{0,20})/,
        /(.{0,20})(拡大|成長|スケール)(.{0,20})/,
        /(.{0,20})(大量|多く|たくさん)(.{0,20})/
      ],
      suggestion_template: 'スケーラビリティ向上プランの提案'
    },
    usability: {
      keywords: %w[難しい 複雑 分かりにくい 使いにくい 分からない 迷う 混乱],
      patterns: [
        /(.{0,20})(難しい|複雑|分かりにくい)(.{0,20})/,
        /(.{0,20})(使いにくい|使い方|操作)(.{0,20})/,
        /(.{0,20})(分からない|迷う|混乱)(.{0,20})/
      ],
      suggestion_template: 'UI/UX改善・トレーニングサポート'
    }
  }.freeze

  # 感情パターンの定義
  SENTIMENT_PATTERNS = {
    frustrated: {
      keywords: %w[困った イライラ うんざり 疲れた 大変 ストレス],
      patterns: [/困っ|イライラ|うんざり|疲れ|大変|ストレス/],
      priority_boost: 2
    },
    urgent: {
      keywords: %w[至急 緊急 今すぐ すぐに 早急 急ぎ],
      patterns: [/至急|緊急|今すぐ|すぐに|早急|急ぎ/],
      priority_boost: 3
    },
    disappointed: {
      keywords: %w[がっかり 期待はずれ 残念 不満],
      patterns: [/がっかり|期待はずれ|残念|不満/],
      priority_boost: 1
    }
  }.freeze

  def initialize
    @detected_needs = []
    @context_buffer = []
  end

  # 会話履歴から隠れたニーズを抽出
  def extract_needs(conversation_history)
    @detected_needs = []
    @context_buffer = []

    # 会話履歴を順番に分析
    conversation_history.each_with_index do |message, index|
      next unless message[:role] == 'user'

      content = message[:content]
      @context_buffer << content

      # パターンマッチングによるニーズ検出
      detect_needs_by_pattern(content, index)

      # コンテキスト分析（前後のメッセージを考慮）
      analyze_context(conversation_history, index) if index > 0
    end

    # 検出されたニーズを統合・優先度付け
    consolidate_and_prioritize_needs
  end

  private

  def detect_needs_by_pattern(content, message_index)
    NEED_PATTERNS.each do |need_type, config|
      # キーワードマッチング
      keyword_score = calculate_keyword_score(content, config[:keywords])

      # パターンマッチング
      config[:patterns].each do |pattern|
        next unless content.match?(pattern)

        match_data = content.match(pattern)
        context = extract_context_from_match(match_data)

        @detected_needs << {
          type: need_type,
          evidence: content,
          context: context,
          confidence: calculate_confidence(keyword_score, pattern),
          message_index: message_index,
          suggestion: generate_suggestion(need_type, context)
        }
      end
    end
  end

  def analyze_context(conversation_history, current_index)
    # 前後3メッセージを分析対象とする
    context_window = 3
    start_index = [0, current_index - context_window].max
    end_index = [conversation_history.length - 1, current_index + context_window].min

    context_messages = conversation_history[start_index..end_index]
    
    # 繰り返し言及されているトピックを検出
    repeated_topics = detect_repeated_topics(context_messages)
    
    # 感情の変化を追跡
    sentiment_progression = track_sentiment_progression(context_messages)
    
    # コンテキストに基づいてニーズを更新
    update_needs_with_context(repeated_topics, sentiment_progression)
  end

  def calculate_keyword_score(content, keywords)
    score = 0
    keywords.each do |keyword|
      score += 1 if content.include?(keyword)
    end
    score.to_f / keywords.length
  end

  def calculate_confidence(keyword_score, pattern)
    base_confidence = 0.5
    
    # キーワードスコアによる調整
    confidence = base_confidence + (keyword_score * 0.3)
    
    # パターンの複雑さによる調整
    pattern_complexity = pattern.source.length / 100.0
    confidence += [pattern_complexity, 0.2].min
    
    [confidence, 1.0].min
  end

  def extract_context_from_match(match_data)
    return '' unless match_data

    # マッチした部分の前後のコンテキストを抽出
    context_parts = []
    match_data.captures.each do |capture|
      next if capture.nil? || capture.strip.empty?
      context_parts << capture.strip
    end
    
    context_parts.join(' ')
  end

  def generate_suggestion(need_type, context)
    template = NEED_PATTERNS[need_type][:suggestion_template]
    
    if context.present?
      format(template, context)
    else
      template.gsub('%s', '業務プロセス')
    end
  end

  def detect_repeated_topics(messages)
    topics = {}
    
    messages.each do |message|
      next unless message[:role] == 'user'
      
      content = message[:content]
      # 名詞を抽出（簡易版）
      words = content.scan(/[一-龠ァ-ヶー]+|[a-zA-Z]+/)
      
      words.each do |word|
        next if word.length < 2
        topics[word] ||= 0
        topics[word] += 1
      end
    end
    
    # 2回以上言及されたトピックを返す
    topics.select { |_, count| count >= 2 }
  end

  def track_sentiment_progression(messages)
    sentiments = []
    
    messages.each do |message|
      next unless message[:role] == 'user'
      
      sentiment = detect_sentiment(message[:content])
      sentiments << sentiment if sentiment
    end
    
    sentiments
  end

  def detect_sentiment(content)
    SENTIMENT_PATTERNS.each do |sentiment_type, config|
      config[:patterns].each do |pattern|
        return sentiment_type if content.match?(pattern)
      end
    end
    
    nil
  end

  def update_needs_with_context(repeated_topics, sentiment_progression)
    # 繰り返されるトピックがあるニーズの信頼度を上げる
    @detected_needs.each do |need|
      repeated_topics.each do |topic, count|
        if need[:evidence].include?(topic)
          need[:confidence] = [need[:confidence] + (count * 0.05), 1.0].min
        end
      end
    end
    
    # ネガティブな感情が検出された場合、優先度を上げる
    if sentiment_progression.any? { |s| [:frustrated, :urgent, :disappointed].include?(s) }
      @detected_needs.each do |need|
        need[:priority_boost] = sentiment_progression.map do |sentiment|
          SENTIMENT_PATTERNS[sentiment]&.dig(:priority_boost) || 0
        end.max
      end
    end
  end

  def consolidate_and_prioritize_needs
    # 重複を除去し、信頼度でソート
    consolidated = @detected_needs.uniq { |n| [n[:type], n[:suggestion]] }
    
    # 優先度スコアを計算
    consolidated.each do |need|
      priority_score = calculate_priority_score(need)
      need[:priority] = determine_priority_level(priority_score)
      need[:priority_score] = priority_score
    end
    
    # 優先度スコアでソート（降順）
    consolidated.sort_by { |n| -n[:priority_score] }
  end

  def calculate_priority_score(need)
    base_score = need[:confidence] * 100
    
    # 優先度ブースト（感情ベース）
    boost = need[:priority_boost] || 0
    base_score *= (1 + boost * 0.3)  # ブースト効果を強化
    
    # ニーズタイプによる重み付け
    type_weights = {
      efficiency: 1.2,
      cost_reduction: 1.1,  # コスト削減の重みを下げる
      feature_request: 1.0,
      integration: 1.1,
      scalability: 1.4,
      usability: 1.1
    }
    
    base_score * (type_weights[need[:type]] || 1.0)
  end

  def determine_priority_level(score)
    case score
    when 120..Float::INFINITY
      'high'
    when 80..119
      'medium'
    else
      'low'
    end
  end
end