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
    
    trait :with_embedding do
      embedding { Array.new(1536) { rand(-1.0..1.0) } }
    end
    
    trait :with_embedding_cluster do
      transient do
        cluster { 'default' }
      end
      
      after(:build) do |message, evaluator|
        # クラスタごとに異なるパターンのベクトルを生成
        case evaluator.cluster
        when 'login'
          message.embedding = Array.new(1536) { |i| Math.sin(i * 0.1) * 0.5 + rand(-0.1..0.1) }
        when 'payment'
          message.embedding = Array.new(1536) { |i| Math.cos(i * 0.1) * 0.5 + rand(-0.1..0.1) }
        when 'shipping'
          message.embedding = Array.new(1536) { |i| Math.sin(i * 0.2) * 0.5 + rand(-0.1..0.1) }
        else
          message.embedding = Array.new(1536) { rand(-1.0..1.0) }
        end
      end
    end
  end
end
