# frozen_string_literal: true

# ニーズプレビュー機能のFeature Flags / チューニング設定
Rails.application.configure do
  config.x.needs_preview = ActiveSupport::InheritableOptions.new(
    enabled: true,
    turn_threshold_min: 2,
    turn_threshold_max: 3,
    min_confidence: 0.6,
    ask_clarifying: true,
    max_followups: 3,
    similarity_weight: 0.4,
    category_weight: 0.2,
    llm_weight: 0.4, # 予約（将来、LLM信頼度を合成する時に使用）
    cooldown_sec: 45 # 予約
  )
end


