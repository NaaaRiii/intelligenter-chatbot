# frozen_string_literal: true

require 'rails_helper'

RSpec.describe HybridAnalysisJob, type: :job do
  let(:user) { create(:user) }
  let(:conversation) { create(:conversation, user: user) }

  describe '#perform' do
    before do
      # 会話履歴を作成
      create(:message, conversation: conversation, role: 'user', 
             content: 'システムが遅くて困っています')
      create(:message, conversation: conversation, role: 'assistant',
             content: 'どの処理が遅いでしょうか？')
      create(:message, conversation: conversation, role: 'user',
             content: '月次レポートの生成に3時間もかかります')
    end

    it 'ジョブをキューに追加する' do
      expect {
        described_class.perform_later(conversation.id)
      }.to have_enqueued_job(described_class)
        .with(conversation.id)
        .on_queue('default')
    end

    context '正常な分析処理' do
      it '会話を分析して結果を保存する' do
        expect {
          described_class.perform_now(conversation.id)
        }.to change { conversation.analyses.count }.by(1)

        analysis = conversation.analyses.last
        expect(analysis.analysis_type).to eq('needs')
        expect(analysis.hidden_needs).not_to be_empty
        expect(analysis.priority_level).to be_present
      end

      it '効率化ニーズを検出する' do
        described_class.perform_now(conversation.id)

        analysis = conversation.analyses.last
        efficiency_need = analysis.hidden_needs.find { |n| n['need_type'] == 'efficiency' }
        
        expect(efficiency_need).not_to be_nil
        expect(efficiency_need['evidence']).to include('遅く')
        expect(efficiency_need['proactive_suggestion']).to include('効率化')
      end

      it '信頼度スコアを計算する' do
        described_class.perform_now(conversation.id)

        analysis = conversation.analyses.last
        expect(analysis.confidence_score).to be_positive
        expect(analysis.confidence_score).to be <= 1.0
      end

      it '分析時刻を記録する' do
        described_class.perform_now(conversation.id)

        analysis = conversation.analyses.last
        expect(analysis.analyzed_at).to be_present
        expect(analysis.analyzed_at).to be_within(2.seconds).of(Time.current)
      end
    end

    context 'エスカレーションが必要な場合' do
      before do
        # 高優先度のメッセージを追加
        create(:message, conversation: conversation, role: 'user',
               content: '至急改善してください！イライラします')
        
        # EscalationNotifierのモック
        stub_const('EscalationNotifier', Class.new do
          # rubocop:disable Naming/PredicateMethod
          def self.to_slack(text, channel:)
            true
          end
          # rubocop:enable Naming/PredicateMethod
        end)
      end

      it 'エスカレーション処理を実行する' do
        described_class.perform_now(conversation.id)

        analysis = conversation.analyses.last
        expect(analysis.escalated).to be true
      end

      it 'Slack通知を送信する' do
        expect(EscalationNotifier).to receive(:to_slack).once
        described_class.perform_now(conversation.id)
      end
    end

    context 'リアルタイム配信' do
      it '分析結果をActionCableで配信する' do
        expect(ActionCable.server).to receive(:broadcast).with(
          "conversation_#{conversation.id}",
          hash_including(
            type: 'analysis_complete',
            analysis: hash_including(
              :hidden_needs,
              :sentiment,
              :priority,
              :confidence_score,
              extraction_method: 'pattern_matching'
            )
          )
        )

        described_class.perform_now(conversation.id)
      end
    end

    context 'エラーが発生した場合' do
      before do
        allow_any_instance_of(NeedsExtractor).to receive(:extract_needs)
          .and_raise(StandardError, 'Analysis Error')
      end

      it 'エラーをログに記録する' do
        expect(Rails.logger).to receive(:error).at_least(:once)
        
        described_class.perform_now(conversation.id)
      end

      it 'フォールバック分析を保存する' do
        expect {
          described_class.perform_now(conversation.id)
        }.to change { conversation.analyses.count }.by(1)

        analysis = conversation.analyses.last
        expect(analysis.analysis_data['error']).to be true
        expect(analysis.priority_level).to eq('low')
        expect(analysis.sentiment).to eq('neutral')
      end
    end

    context '会話履歴が空の場合' do
      let(:empty_conversation) { create(:conversation, user: user) }

      it '空の分析結果を保存する' do
        described_class.perform_now(empty_conversation.id)

        analysis = empty_conversation.analyses.last
        expect(analysis.hidden_needs).to be_empty
        expect(analysis.priority_level).to eq('low')
        expect(analysis.confidence_score).to eq(0.0)
      end
    end

    context '既存の分析がある場合' do
      before do
        create(:analysis, 
               conversation: conversation,
               analysis_type: 'needs',
               analysis_data: { old: true })
      end

      it '既存の分析を更新する' do
        expect {
          described_class.perform_now(conversation.id)
        }.not_to change { conversation.analyses.count }

        analysis = conversation.analyses.find_by(analysis_type: 'needs')
        expect(analysis.analysis_data['old']).to be_nil
        expect(analysis.hidden_needs).not_to be_empty
      end
    end
  end

  describe 'プライベートメソッド' do
    let(:job) { described_class.new }

    describe '#determine_overall_priority' do
      it '最高優先度を返す' do
        needs = [
          { priority: 'low' },
          { priority: 'high' },
          { priority: 'medium' }
        ]
        
        priority = job.send(:determine_overall_priority, needs)
        expect(priority).to eq('high')
      end

      it '空の場合はlowを返す' do
        priority = job.send(:determine_overall_priority, [])
        expect(priority).to eq('low')
      end
    end

    describe '#determine_overall_sentiment' do
      it 'frustatedを検出する' do
        needs = [
          { priority_boost: 2 },
          { priority_boost: 0 }
        ]
        
        sentiment = job.send(:determine_overall_sentiment, needs)
        expect(sentiment).to eq('frustrated')
      end

      it 'ブーストがない場合はneutralを返す' do
        needs = [
          { priority_boost: 0 },
          { priority_boost: nil }
        ]
        
        sentiment = job.send(:determine_overall_sentiment, needs)
        expect(sentiment).to eq('neutral')
      end
    end

    describe '#calculate_average_confidence' do
      it '平均信頼度を計算する' do
        needs = [
          { confidence: 0.8 },
          { confidence: 0.6 },
          { confidence: 0.7 }
        ]
        
        avg = job.send(:calculate_average_confidence, needs)
        expect(avg).to eq(0.7)
      end

      it '空の場合は0を返す' do
        avg = job.send(:calculate_average_confidence, [])
        expect(avg).to eq(0.0)
      end
    end

    describe '#requires_escalation?' do
      it '高優先度かつ高ブーストの場合trueを返す' do
        needs = [
          { priority: 'high', priority_boost: 2 }
        ]
        
        result = job.send(:requires_escalation?, needs)
        expect(result).to be true
      end

      it '条件を満たさない場合falseを返す' do
        needs = [
          { priority: 'medium', priority_boost: 1 }
        ]
        
        result = job.send(:requires_escalation?, needs)
        expect(result).to be false
      end
    end
  end
end