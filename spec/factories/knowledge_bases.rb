# frozen_string_literal: true

FactoryBot.define do
  factory :knowledge_base do
    pattern_type { 'successful_conversation' }
    content do
      {
        'messages' => [
          { 'role' => 'user', 'content' => 'テストメッセージ' },
          { 'role' => 'assistant', 'content' => 'テスト応答' }
        ]
      }
    end
    summary { 'テスト会話の要約' }
    success_score { 75 }
    metadata { { 'test' => true } }
    tags { ['test'] }
    
    trait :high_score do
      success_score { 90 }
      tags { ['high_score', 'successful'] }
    end
    
    trait :low_score do
      success_score { 30 }
      pattern_type { 'failed_conversation' }
      tags { ['low_score', 'failed'] }
    end
    
    trait :with_conversation do
      association :conversation
    end
    
    trait :with_embedding do
      embedding { Array.new(1536) { rand(-1.0..1.0) } }
    end
  end
end