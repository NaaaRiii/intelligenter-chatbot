# frozen_string_literal: true

module Types
  # メッセージのGraphQL型定義
  class MessageType < Types::BaseObject
    field :id, ID, null: false
    field :conversation_id, ID, null: false
    field :content, String, null: false
    field :role, String, null: false
    field :metadata, GraphQL::Types::JSON, null: true
    field :created_at, GraphQL::Types::ISO8601DateTime, null: false
    field :updated_at, GraphQL::Types::ISO8601DateTime, null: false

    field :conversation, Types::ConversationType, null: false
    field :word_count, Integer, null: false
    field :is_from_user, Boolean, null: false
    field :is_from_assistant, Boolean, null: false

    def is_from_user
      object.from_user?
    end

    def is_from_assistant
      object.from_assistant?
    end
  end
end
