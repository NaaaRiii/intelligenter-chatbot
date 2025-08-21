FactoryBot.define do
  factory :conversation do
    user
    session_id { SecureRandom.uuid }
    ended_at { nil }

    trait :ended do
      ended_at { 1.hour.ago }
    end
  end
end
