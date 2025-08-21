# frozen_string_literal: true

module Types
  # 会話のGraphQL型定義
  class ConversationType < Types::BaseObject
    field :id, ID, null: false
    field :session_id, String, null: false
    field :user_id, ID, null: false
    field :ended_at, GraphQL::Types::ISO8601DateTime, null: true
    field :metadata, GraphQL::Types::JSON, null: true
    field :created_at, GraphQL::Types::ISO8601DateTime, null: false
    field :updated_at, GraphQL::Types::ISO8601DateTime, null: false

    field :user, Types::UserType, null: false
    field :messages, [Types::MessageType], null: false
    field :analyses, [Types::AnalysisType], null: false
    field :message_count, Integer, null: false
    field :duration, Integer, null: true
    field :is_active, Boolean, null: false

    def message_count
      object.messages.count
    end

    def is_active
      object.active?
    end
  end
end
