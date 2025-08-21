# frozen_string_literal: true

module Types
  class MutationType < Types::BaseObject
    # 会話関連
    field :create_conversation, mutation: Mutations::CreateConversation
    
    # メッセージ関連
    field :create_message, mutation: Mutations::CreateMessage
    
    # 分析関連
    field :trigger_analysis, mutation: Mutations::TriggerAnalysis
  end
end
