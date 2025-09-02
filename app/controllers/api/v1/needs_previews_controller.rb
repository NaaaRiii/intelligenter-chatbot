# frozen_string_literal: true

module Api
  module V1
    # 直近の needs_preview 分析を横断的に取得するAPI
    class NeedsPreviewsController < BaseController
      # ダッシュボード閲覧用途のため index は認証をスキップ（開発/社内用途）
      skip_before_action :authenticate_api_user!, only: [:index]
      def index
        limit = (params[:limit] || 20).to_i.clamp(1, 100)

        previews = Analysis
                   .by_type('needs_preview')
                   .includes(:conversation)
                   .order(created_at: :desc)
                   .limit(limit)

        render json: {
          previews: previews.map { |a| serialize_preview(a) }
        }
      end

      private

      def serialize_preview(analysis)
        conv = analysis.conversation
        data = analysis.analysis_data || {}
        meta = conv.metadata || {}

        {
          conversation_id: conv.id,
          timestamp: analysis.created_at,
          category: data['category'] || meta['category'],
          need_type: data['need_type'],
          keywords: (data['keywords'] || []).first(8),
          confidence: analysis.confidence_score,
          company_name: meta['company'] || meta['companyName'] || '不明'
        }
      end
    end
  end
end


