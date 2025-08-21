FactoryBot.define do
  factory :user do
    sequence(:email) { |n| "user#{n}@example.com" }
    name { Faker::Name.name }
    last_active_at { Time.current }

    # APIトークンを自動生成するためにコールバックを使用
    after(:build) do |user|
      user.send(:generate_api_token) if user.api_token.nil?
    end
  end
end
