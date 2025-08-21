FactoryBot.define do
  factory :message do
    conversation
    content { Faker::Lorem.sentence }
    role { 'user' }
    metadata { {} }
    
    trait :assistant do
      role { 'assistant' }
    end
    
    trait :system do
      role { 'system' }
    end
  end
end