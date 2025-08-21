# frozen_string_literal: true

module Types
  class QueryType < Types::BaseObject
    field :node, Types::NodeType, null: true, description: "Fetches an object given its ID." do
      argument :id, ID, required: true, description: "ID of the object."
    end

    def node(id:)
      context.schema.object_from_id(id, context)
    end

    field :nodes, [Types::NodeType, null: true], null: true, description: "Fetches a list of objects given a list of IDs." do
      argument :ids, [ID], required: true, description: "IDs of the objects."
    end

    def nodes(ids:)
      ids.map { |id| context.schema.object_from_id(id, context) }
    end

    # Add root-level fields here.
    # They will be entry points for queries on your schema.

    # ユーザー関連
    field :current_user, Types::UserType, null: true,
          description: '現在のユーザー情報を取得'
    def current_user
      context[:current_user]
    end

    field :user, Types::UserType, null: true do
      description 'ID指定でユーザーを取得'
      argument :id, ID, required: true
    end
    def user(id:)
      User.find(id)
    end

    # 会話関連
    field :conversations, [Types::ConversationType], null: false do
      description '会話一覧を取得'
      argument :user_id, ID, required: false
      argument :active_only, Boolean, required: false, default_value: false
      argument :limit, Integer, required: false, default_value: 20
    end
    def conversations(user_id: nil, active_only: false, limit: 20)
      scope = Conversation.all
      scope = scope.where(user_id: user_id) if user_id
      scope = scope.active if active_only
      scope.recent.limit(limit)
    end

    field :conversation, Types::ConversationType, null: true do
      description 'ID指定で会話を取得'
      argument :id, ID, required: true
    end
    def conversation(id:)
      Conversation.find(id)
    end

    # メッセージ関連
    field :messages, [Types::MessageType], null: false do
      description '会話のメッセージ一覧を取得'
      argument :conversation_id, ID, required: true
      argument :limit, Integer, required: false, default_value: 50
    end
    def messages(conversation_id:, limit: 50)
      Message.where(conversation_id: conversation_id)
             .chronological
             .limit(limit)
    end

    # 分析関連
    field :analyses, [Types::AnalysisType], null: false do
      description '分析結果一覧を取得'
      argument :conversation_id, ID, required: false
      argument :analysis_type, String, required: false
      argument :priority_level, String, required: false
      argument :limit, Integer, required: false, default_value: 20
    end
    def analyses(conversation_id: nil, analysis_type: nil, priority_level: nil, limit: 20)
      scope = Analysis.all
      scope = scope.where(conversation_id: conversation_id) if conversation_id
      scope = scope.where(analysis_type: analysis_type) if analysis_type
      scope = scope.where(priority_level: priority_level) if priority_level
      scope.recent.limit(limit)
    end
  end
end
