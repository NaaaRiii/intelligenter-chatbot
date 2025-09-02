# frozen_string_literal: true

class ResolutionPath < ApplicationRecord
  # バリデーション
  validates :problem_type, presence: true
  validates :steps_count, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true
  validates :resolution_time, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true

  # スコープ
  scope :successful, -> { where(successful: true) }
  scope :failed, -> { where(successful: false) }
  scope :by_problem_type, ->(type) { where(problem_type: type) }
  scope :optimal, -> { successful.order(steps_count: :asc, resolution_time: :asc) }

  # メソッド
  def efficiency_score
    return 0 unless successful && steps_count && resolution_time

    # ステップ数と時間から効率スコアを計算
    step_score = [100 - (steps_count * 10), 0].max
    time_score = [100 - (resolution_time / 60), 0].max  # 分単位で計算
    
    (step_score + time_score) / 2
  end

  def add_key_action(action)
    self.key_actions ||= []
    self.key_actions << action
    save
  end

  def time_in_minutes
    return nil unless resolution_time
    resolution_time / 60.0
  end
end