# frozen_string_literal: true

module Mutations
  # 分析トリガーのMutation
  class TriggerAnalysis < BaseMutation
    # 引数
    argument :conversation_id, ID, required: true

    # 戻り値の型
    field :success, Boolean, null: false
    field :message, String, null: false

    def resolve(conversation_id:)
      conversation = Conversation.find(conversation_id)
      AnalyzeConversationJob.perform_later(conversation.id)

      {
        success: true,
        message: "会話ID #{conversation.id} の分析をトリガーしました"
      }
    rescue ActiveRecord::RecordNotFound
      {
        success: false,
        message: '指定された会話が見つかりません'
      }
    end
  end
end