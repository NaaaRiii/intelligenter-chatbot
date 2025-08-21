# frozen_string_literal: true

module Mutations
  # メッセージ作成のMutation
  class CreateMessage < BaseMutation
    # 引数
    argument :conversation_id, ID, required: true
    argument :content, String, required: true
    argument :role, String, required: true
    argument :metadata, GraphQL::Types::JSON, required: false

    # 戻り値の型
    field :message, Types::MessageType, null: true
    field :errors, [String], null: false

    def resolve(conversation_id:, content:, role:, metadata: nil)
      conversation = Conversation.find(conversation_id)
      message = conversation.messages.build(
        content: content,
        role: role,
        metadata: metadata
      )

      if message.save
        # AI応答をトリガー
        ProcessAiResponseJob.perform_later(message.id) if message.from_user?

        {
          message: message,
          errors: []
        }
      else
        {
          message: nil,
          errors: message.errors.full_messages
        }
      end
    end
  end
end