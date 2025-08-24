# frozen_string_literal: true

# rubocop:disable RSpec/ContextWording, RSpec/MessageSpies

require 'rails_helper'

RSpec.describe AnalyzeConversationJob, type: :job do
  include ActiveJob::TestHelper

  let(:user) { create(:user) }
  let(:conversation) { create(:conversation, user: user) }
  let(:messages) do
    [
      create(:message, conversation: conversation, role: 'user', content: 'システムが遅いです'),
      create(:message, conversation: conversation, role: 'assistant', content: 'どのような処理が遅いですか？'),
      create(:message, conversation: conversation, role: 'user', content: 'レポート生成です')
    ]
  end

  let(:analysis_result) do
    {
      'hidden_needs' => [
        {
          'need_type' => '効率化',
          'evidence' => 'レポート生成が遅い',
          'confidence' => 0.8,
          'proactive_suggestion' => 'キャッシュ機能の導入'
        }
      ],
      'customer_sentiment' => 'frustrated',
      'priority_level' => 'high',
      'escalation_required' => true,
      'escalation_reason' => 'パフォーマンス問題'
    }
  end

  describe '#perform' do
    before do
      # 会話履歴のセットアップを明示的に実行
      messages
      allow_any_instance_of(ClaudeApiService).to receive(:analyze_conversation).and_return(analysis_result)
      # エラーログを確認するためにログレベルを調整
      allow(Rails.logger).to receive(:error) do |msg|
        puts "ERROR LOG: #{msg}"
      end
      allow(Rails.logger).to receive(:info)
    end

    it 'ジョブをキューに追加する' do
      expect do
        described_class.perform_later(conversation.id)
      end.to have_enqueued_job(described_class).with(conversation.id)
    end

    context '正常な分析処理' do
      it '会話を分析して結果を保存する' do # rubocop:disable RSpec/MultipleExpectations
        # 既存のanalysisがあるかもしれないので、まず削除
        conversation.analyses.destroy_all

        described_class.perform_now(conversation.id)

        # 複数作成される可能性を考慮してreloadしてチェック
        conversation.reload
        analyses = conversation.analyses

        # デバッグ出力
        if analyses.count != 1
          analyses.each do |a|
            puts "Analysis: type=#{a.analysis_type}, sentiment=#{a.sentiment}, created_at=#{a.created_at}"
          end
        end

        expect(analyses.count).to eq(1)

        analysis = analyses.last
        expect(analysis.analysis_type).to eq('needs')
        expect(analysis.sentiment).to eq('frustrated')
        expect(analysis.priority_level).to eq('high')
        expect(analysis.hidden_needs).to eq(analysis_result['hidden_needs'])
        expect(analysis.escalation_reason).to eq('パフォーマンス問題')
        expect(analysis.analysis_data).to eq(analysis_result)
      end # rubocop:enable RSpec/MultipleExpectations

      it '分析時刻を記録する' do
        described_class.perform_now(conversation.id)

        analysis = conversation.analyses.last
        expect(analysis.analyzed_at).to be_within(1.second).of(Time.current)
      end

      it '信頼度スコアを計算する' do
        # 既存のanalysisがあるかもしれないので、まず削除
        conversation.analyses.destroy_all

        described_class.perform_now(conversation.id)

        analysis = conversation.analyses.where(analysis_type: 'needs').last
        expect(analysis.confidence_score).to eq(0.8)
      end
    end

    context 'エスカレーションが必要な場合' do
      before do
        allow_any_instance_of(described_class).to receive(:slack_configured?).and_return(true)
        allow_any_instance_of(described_class).to receive(:email_configured?).and_return(false)
        allow(EscalationNotifier).to receive(:to_slack).and_return(true)
      end

      it 'エスカレーション処理を実行する' do
        expect(EscalationNotifier).to receive(:to_slack).once

        described_class.perform_now(conversation.id)

        analysis = conversation.analyses.last
        analysis.reload # データベースから最新の状態を取得
        expect(analysis.escalated).to be true
        expect(analysis.escalated_at).to be_present
      end
    end

    context 'リアルタイム配信' do
      it '分析結果をActionCableで配信する' do
        expect(ActionCable.server).to receive(:broadcast).with(
          "conversation_#{conversation.id}",
          hash_including(
            type: 'analysis_complete',
            analysis: hash_including(
              hidden_needs: analysis_result['hidden_needs'],
              sentiment: 'frustrated',
              priority: 'high'
            )
          )
        )

        described_class.perform_now(conversation.id)
      end
    end

    context 'エラーが発生した場合' do
      before do
        allow_any_instance_of(ClaudeApiService).to receive(:analyze_conversation).and_raise(StandardError, 'API Error')
      end

      it 'エラーをログに記録する' do
        expect(Rails.logger).to receive(:error).with(/Analysis failed/)
        expect(Rails.logger).to receive(:error).at_least(:once)

        described_class.perform_now(conversation.id)
      end

      it 'フォールバック分析を保存する' do
        expect do
          described_class.perform_now(conversation.id)
        end.to change(conversation.analyses, :count).by(1)

        analysis = conversation.analyses.last
        expect(analysis.analysis_data['error']).to eq('API Error')
        expect(analysis.analysis_data['fallback']).to be true
        expect(analysis.sentiment).to eq('neutral')
        expect(analysis.priority_level).to eq('low')
      end
    end

    context '会話履歴が空の場合' do
      let(:empty_conversation) { create(:conversation, user: user) }

      it '処理をスキップする' do
        expect_any_instance_of(ClaudeApiService).not_to receive(:analyze_conversation)

        expect do
          described_class.perform_now(empty_conversation.id)
        end.not_to change(Analysis, :count)
      end
    end

    context '既存の分析がある場合' do
      let!(:existing_analysis) do
        create(
          :analysis,
          conversation: conversation,
          analysis_type: 'needs',
          sentiment: 'neutral',
          priority_level: 'low'
        )
      end

      it '既存の分析を更新する' do
        expect do
          described_class.perform_now(conversation.id)
        end.not_to change(conversation.analyses, :count)

        existing_analysis.reload
        expect(existing_analysis.sentiment).to eq('frustrated')
        expect(existing_analysis.priority_level).to eq('high')
      end
    end
  end

  describe 'プライベートメソッド' do
    let(:job) { described_class.new }

    describe '#requires_escalation?' do
      it 'escalation_requiredがtrueの場合にtrueを返す' do
        result = { 'escalation_required' => true }
        expect(job.send(:requires_escalation?, result)).to be true
      end

      it 'priority_levelがhighの場合にtrueを返す' do
        result = { 'priority_level' => 'high' }
        expect(job.send(:requires_escalation?, result)).to be true
      end

      it 'customer_sentimentがfrustratedの場合にtrueを返す' do
        result = { 'customer_sentiment' => 'frustrated' }
        expect(job.send(:requires_escalation?, result)).to be true
      end

      it 'いずれの条件も満たさない場合はfalseを返す' do
        result = { 'priority_level' => 'low', 'customer_sentiment' => 'neutral' }
        expect(job.send(:requires_escalation?, result)).to be false
      end
    end

    describe '#calculate_average_confidence' do
      it '平均信頼度を計算する' do
        result = {
          'hidden_needs' => [
            { 'confidence' => 0.8 },
            { 'confidence' => 0.6 },
            { 'confidence' => 0.7 }
          ]
        }

        avg = job.send(:calculate_average_confidence, result)
        expect(avg).to be_within(0.01).of(0.7)
      end

      it 'hidden_needsが空の場合は0を返す' do
        result = { 'hidden_needs' => [] }

        avg = job.send(:calculate_average_confidence, result)
        expect(avg).to eq(0.0)
      end
    end
  end
end
# rubocop:enable RSpec/ContextWording, RSpec/MessageSpies
