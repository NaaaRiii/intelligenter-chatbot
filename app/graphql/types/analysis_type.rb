# frozen_string_literal: true

module Types
  # 分析結果のGraphQL型定義
  class AnalysisType < Types::BaseObject
    field :id, ID, null: false
    field :conversation_id, ID, null: false
    field :analysis_type, String, null: false
    field :analysis_data, GraphQL::Types::JSON, null: false
    field :sentiment, String, null: true
    field :priority_level, String, null: false
    field :escalated, Boolean, null: false
    field :escalated_at, GraphQL::Types::ISO8601DateTime, null: true
    field :created_at, GraphQL::Types::ISO8601DateTime, null: false
    field :updated_at, GraphQL::Types::ISO8601DateTime, null: false

    field :conversation, Types::ConversationType, null: false
    field :hidden_needs, [GraphQL::Types::JSON], null: false
    field :sentiment_score, Float, null: true
    field :requires_escalation, Boolean, null: false, method: :requires_escalation?
  end
end
