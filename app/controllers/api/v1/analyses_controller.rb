# frozen_string_literal: true

module Api
  module V1
    # 分析結果のRESTful APIコントローラー
    class AnalysesController < BaseController
      before_action :set_conversation
      before_action :set_analysis, only: :show

      # GET /api/v1/conversations/:conversation_id/analyses
      def index
        @analyses = @conversation.analyses
                                 .recent
                                 .page(params[:page])
                                 .per(params[:per_page] || 20)

        render json: {
          analyses: @analyses.map { |a| analysis_json(a) },
          meta: pagination_meta(@analyses)
        }
      end

      # GET /api/v1/conversations/:conversation_id/analyses/:id
      def show
        render json: analysis_json(@analysis, detailed: true)
      end

      # POST /api/v1/conversations/:conversation_id/analyses/trigger
      def trigger
        AnalyzeConversationJob.perform_later(@conversation.id)

        render json: {
          message: '分析をトリガーしました',
          conversation_id: @conversation.id
        }, status: :accepted
      end

      private

      def set_conversation
        @conversation = current_user.conversations.find(params[:conversation_id])
      end

      def set_analysis
        @analysis = @conversation.analyses.find(params[:id])
      end

      def analysis_json(analysis, detailed: false)
        json = {
          id: analysis.id,
          conversation_id: analysis.conversation_id,
          analysis_type: analysis.analysis_type,
          sentiment: analysis.sentiment,
          priority_level: analysis.priority_level,
          escalated: analysis.escalated,
          created_at: analysis.created_at
        }

        if detailed
          json.merge!(
            analysis_data: analysis.analysis_data,
            hidden_needs: analysis.hidden_needs,
            sentiment_score: analysis.sentiment_score,
            requires_escalation: analysis.requires_escalation?
          )
        end

        json
      end

      def pagination_meta(collection)
        {
          current_page: collection.current_page,
          total_pages: collection.total_pages,
          total_count: collection.total_count,
          per_page: collection.limit_value
        }
      end
    end
  end
end
