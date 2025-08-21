# frozen_string_literal: true

module Types
  # ユーザーのGraphQL型定義
  class UserType < Types::BaseObject
    field :id, ID, null: false
    field :email, String, null: false
    field :name, String, null: false
    field :last_active_at, GraphQL::Types::ISO8601DateTime, null: true
    field :created_at, GraphQL::Types::ISO8601DateTime, null: false
    field :updated_at, GraphQL::Types::ISO8601DateTime, null: false

    field :conversation_count, Integer, null: false
    field :average_sentiment_score, Float, null: true
    field :conversations, [Types::ConversationType], null: false

    def conversation_count
      object.conversation_count
    end

    def average_sentiment_score
      object.average_sentiment_score
    end
  end
end