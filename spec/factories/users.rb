FactoryBot.define do
  factory :user do
    sequence(:email) { |n| "user#{n}@example.com" }
    name { Faker::Name.name }
    last_active_at { Time.current }
  end
end