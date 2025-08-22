# frozen_string_literal: true

# ユーザーメッセージの意図認識クラス
class IntentRecognizer
  attr_reader :message

  # キーワードマッピング
  INTENT_KEYWORDS = {
    greeting: %w[こんにちは おはよう こんばんは はじめまして よろしく],
    question: %w[？ ? 教えて どうやって なぜ どうして いつ どこ 何],
    complaint: %w[困った エラー 動かない おかしい 不具合 バグ 失敗 できない],
    feedback: %w[改善 提案 要望 意見 フィードバック より良く],
    thanks: %w[ありがとう 感謝 助かった お礼],
    goodbye: %w[さようなら またね 失礼 終了 バイバイ]
  }.freeze

  # 意図の優先順位
  INTENT_PRIORITY = %i[complaint question greeting feedback thanks goodbye].freeze

  def initialize(message:)
    @message = message.to_s.downcase
  end

  # 意図を認識
  def recognize
    return { type: 'general', confidence: 0.3, keywords: [] } if @message.blank?

    detected_intents = detect_intents

    if detected_intents.any?
      best_intent = select_best_intent(detected_intents)
      {
        type: best_intent[:type].to_s,
        confidence: best_intent[:confidence],
        keywords: best_intent[:keywords]
      }
    else
      {
        type: 'general',
        confidence: 0.5,
        keywords: extract_general_keywords
      }
    end
  end

  # 意図の詳細分析
  def analyze_sentiment
    positive_words = %w[嬉しい 良い 素晴らしい 最高 便利 助かる]
    negative_words = %w[悪い 最悪 ひどい 困る 不満 イライラ]

    positive_score = count_word_matches(positive_words)
    negative_score = count_word_matches(negative_words)

    if positive_score > negative_score
      'positive'
    elsif negative_score > positive_score
      'negative'
    else
      'neutral'
    end
  end

  private

  # 意図を検出
  def detect_intents
    intents = []

    INTENT_KEYWORDS.each do |intent_type, keywords|
      matched_keywords = find_matching_keywords(keywords)

      next if matched_keywords.empty?

      confidence = calculate_confidence(matched_keywords, keywords)
      intents << {
        type: intent_type,
        confidence: confidence,
        keywords: matched_keywords
      }
    end

    intents
  end

  # マッチするキーワードを検索
  def find_matching_keywords(keywords)
    keywords.select { |keyword| @message.include?(keyword) }
  end

  # 信頼度を計算
  def calculate_confidence(matched_keywords, all_keywords)
    base_confidence = matched_keywords.size.to_f / all_keywords.size

    # メッセージ長による調整
    length_factor = [@message.length / 100.0, 1.0].min

    # 複数マッチによるボーナス
    multi_match_bonus = matched_keywords.size > 1 ? 0.2 : 0

    [(base_confidence + (length_factor * 0.3) + multi_match_bonus), 1.0].min
  end

  # 最適な意図を選択
  def select_best_intent(intents)
    # 優先順位と信頼度を考慮
    intents.min_by do |intent|
      priority_index = INTENT_PRIORITY.index(intent[:type]) || INTENT_PRIORITY.size
      [-intent[:confidence], priority_index]
    end
  end

  # 一般的なキーワードを抽出
  def extract_general_keywords
    # 重要そうな単語を抽出（簡易版）
    @message.scan(/[一-龠ぁ-ゔァ-ヴー]{2,}/)
            .reject { |w| w.length > 10 }
            .first(3)
  end

  # 単語マッチ数をカウント
  def count_word_matches(words)
    words.count { |word| @message.include?(word) }
  end
end
