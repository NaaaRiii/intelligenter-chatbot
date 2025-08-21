FactoryBot.define do
  factory :analysis do
    conversation
    analysis_type { 'needs' }
    analysis_data { { 'content' => 'test' } }
    priority_level { 'medium' }
    sentiment { 'neutral' }
    escalated { false }
    escalated_at { nil }

    trait :high_priority do
      priority_level { 'high' }
    end

    trait :escalated do
      escalated { true }
      escalated_at { Time.current }
    end

    trait :frustrated do
      sentiment { 'frustrated' }
    end
  end
end
