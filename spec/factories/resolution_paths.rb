# frozen_string_literal: true

FactoryBot.define do
  factory :resolution_path do
    problem_type { 'general_issue' }
    solution { 'General solution' }
    steps_count { 3 }
    resolution_time { 180 } # 3 minutes in seconds
    successful { true }
    key_actions { ['step1', 'step2', 'step3'] }
    metadata { {} }
  end
end