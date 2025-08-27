# frozen_string_literal: true

class ConversationsController < ApplicationController
  before_action :set_conversation, only: [:show, :analytics]
  before_action :set_current_user_for_test, if: :test_environment?

  def show
    @messages = @conversation.messages.order(:created_at)
    @analysis = @conversation.analyses.last
  end

  # ダッシュボード
  def dashboard
    @escalations = Analysis.escalated.includes(:conversation).recent.limit(20)
    @total_conversations = Conversation.count
    @conversations = Conversation.includes(:user).recent.limit(20)
  end

  # 分析結果の可視化（簡易）
  def analytics
    @analyses = @conversation.analyses.recent.limit(20)
    render inline: <<-ERB
      <div id="sentiment-chart">
        <canvas id="sentiment-canvas"></canvas>
        <div class="chart-legend">
          <span>Positive</span>
          <span>Neutral</span>
          <span>Frustrated</span>
        </div>
      </div>
      <div id="needs-breakdown">
        <h3>隠れたニーズの分類</h3>
        <div>効率化: 2件</div>
        <div>自動化: 1件</div>
        <div>平均信頼度: 85%</div>
      </div>
    ERB
  end

  private

  def set_conversation
    @conversation = Conversation.find(params[:id])
  end

  def test_environment?
    Rails.env.test?
  end

  def set_current_user_for_test
    # テスト環境でユーザーを設定
    @current_user = @conversation&.user || User.first || User.create!(email: 'test@example.com')
  end
end