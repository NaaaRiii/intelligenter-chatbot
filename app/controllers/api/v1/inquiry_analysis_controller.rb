# frozen_string_literal: true

module Api
  module V1
    # 問い合わせ内容の自動分析APIコントローラー
    class InquiryAnalysisController < BaseController
      skip_before_action :authenticate_user!, only: [:analyze]

      # POST /api/v1/inquiry_analysis/analyze
      def analyze
        message = params[:message]
        conversation_history = params[:conversation_history] || []

        if message.blank?
          render json: { error: 'メッセージが必要です' }, status: :unprocessable_entity
          return
        end

        analyzer = InquiryAnalyzerService.new
        analysis = analyzer.analyze(message, conversation_history)

        # レスポンスを整形
        response = {
          category: analysis[:category],
          intent: analysis[:intent],
          urgency: analysis[:urgency],
          keywords: analysis[:keywords],
          entities: analysis[:entities],
          sentiment: analysis[:sentiment],
          customer_profile: analysis[:customer_profile],
          required_info: analysis[:required_info],
          suggested_action: analysis[:next_action],
          analysis_timestamp: Time.current.iso8601,
          metadata: build_metadata(analysis)
        }

        render json: response
      end

      # POST /api/v1/inquiry_analysis/batch_analyze
      def batch_analyze
        messages = params[:messages] || []
        
        if messages.empty?
          render json: { error: 'メッセージが必要です' }, status: :unprocessable_entity
          return
        end

        analyzer = InquiryAnalyzerService.new
        results = messages.map do |msg|
          analysis = analyzer.analyze(msg[:content], msg[:history] || [])
          {
            message_id: msg[:id],
            analysis: format_analysis(analysis)
          }
        end

        render json: { results: results }
      end

      private

      def build_metadata(analysis)
        {
          has_budget: analysis[:entities][:budget].present?,
          has_timeline: analysis[:entities][:timeline].present?,
          needs_escalation: analysis[:urgency] == 'high',
          confidence_score: calculate_confidence(analysis)
        }
      end

      def format_analysis(analysis)
        {
          category: analysis[:category],
          intent: analysis[:intent],
          urgency: analysis[:urgency],
          keywords: analysis[:keywords],
          sentiment: analysis[:sentiment]
        }
      end

      def calculate_confidence(analysis)
        score = 0.5
        score += 0.1 if analysis[:category] != 'general'
        score += 0.1 if analysis[:intent] != 'general_inquiry'
        score += 0.1 if analysis[:keywords].any?
        score += 0.1 if analysis[:entities].any?
        score += 0.1 if analysis[:customer_profile][:industry].present?
        [score, 1.0].min
      end
    end
  end
end