# frozen_string_literal: true

module Mutations
  # 会話作成のMutation
  class CreateConversation < BaseMutation
    # 引数
    argument :user_id, ID, required: true
    argument :session_id, String, required: false
    argument :metadata, GraphQL::Types::JSON, required: false

    # 戻り値の型
    field :conversation, Types::ConversationType, null: true
    field :errors, [String], null: false

    def resolve(user_id:, session_id: nil, metadata: nil)
      user = User.find(user_id)
      conversation = user.conversations.build(
        session_id: session_id || SecureRandom.uuid,
        metadata: metadata
      )

      if conversation.save
        {
          conversation: conversation,
          errors: []
        }
      else
        {
          conversation: nil,
          errors: conversation.errors.full_messages
        }
      end
    end
  end
end
