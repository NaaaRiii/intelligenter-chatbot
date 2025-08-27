# frozen_string_literal: true

require 'rails_helper'
require 'sidekiq/testing'

RSpec.describe EscalationNotificationWorker, type: :worker do
  let(:conversation) { create(:conversation) }
  let(:analysis) do
    create(:analysis,
           conversation: conversation,
           priority_level: 'high',
           sentiment: 'frustrated',
           escalated: false,
           escalation_reasons: 'Customer extremely frustrated')
  end
  let(:worker) { described_class.new }

  describe 'Sidekiq設定' do
    it 'criticalキューを使用する' do
      expect(described_class.get_sidekiq_options['queue']).to eq('critical')
    end

    it '高いリトライ回数を持つ' do
      expect(described_class.get_sidekiq_options['retry']).to eq(10)
    end
  end

  describe '#perform' do
    context '通知タイプがemailの場合' do
      it 'メール通知を送信する' do
        expect(Rails.logger).to receive(:info)
          .with("Processing escalation notification for analysis ##{analysis.id}")
        expect(Rails.logger).to receive(:info)
          .with("Email notification would be sent for analysis ##{analysis.id}")
        expect(Rails.logger).to receive(:info)
          .with("Completed escalation notification for analysis ##{analysis.id}")

        worker.perform(analysis.id, 'email')
      end
    end

    context '通知タイプがslackの場合' do
      context 'Slack Webhookが設定されている場合' do
        before do
          allow(ENV).to receive(:fetch).and_call_original
          allow(ENV).to receive(:[]).and_call_original
          allow(ENV).to receive(:[]).with('SLACK_WEBHOOK_URL').and_return('https://hooks.slack.com/test')
        end

        it 'Slack通知を送信する' do
          # Slack Webhook へのHTTPリクエストをモック
          stub_request(:post, 'https://hooks.slack.com/test')
            .to_return(status: 200, body: 'ok')
          
          expect(Rails.logger).to receive(:info)
            .with("Processing escalation notification for analysis ##{analysis.id}")
          expect(Rails.logger).to receive(:info)
            .with("Sending Slack notification for analysis ##{analysis.id}")
          expect(Rails.logger).to receive(:info)
            .with("Slack notification sent with status: 200")
          expect(Rails.logger).to receive(:info)
            .with("Completed escalation notification for analysis ##{analysis.id}")

          worker.perform(analysis.id, 'slack')
          
          # HTTPリクエストが送信されたことを確認
          expect(WebMock).to have_requested(:post, 'https://hooks.slack.com/test')
            .with(headers: { 'Content-Type' => 'application/json' })
        end
      end

      context 'Slack Webhookが設定されていない場合' do
        before do
          allow(ENV).to receive(:fetch).and_call_original
          allow(ENV).to receive(:[]).and_call_original
          allow(ENV).to receive(:[]).with('SLACK_WEBHOOK_URL').and_return(nil)
        end

        it 'Slack通知をスキップする' do
          expect(Rails.logger).to receive(:info)
            .with("Processing escalation notification for analysis ##{analysis.id}")
          expect(Rails.logger).not_to receive(:info)
            .with(/Sending Slack notification/)
          expect(Rails.logger).to receive(:info)
            .with("Completed escalation notification for analysis ##{analysis.id}")

          worker.perform(analysis.id, 'slack')
        end
      end
    end

    context '通知タイプがdashboardの場合' do
      it 'ダッシュボードにブロードキャストする' do
        expect(ActionCable.server).to receive(:broadcast).with(
          'escalation_channel',
          hash_including(
            type: 'new_escalation',
            analysis_id: analysis.id,
            priority: 'high'
          )
        )

        worker.perform(analysis.id, 'dashboard')
      end
    end

    context '通知タイプがallの場合' do
      it 'すべての通知を送信する' do
        expect(Rails.logger).to receive(:info)
          .with("Processing escalation notification for analysis ##{analysis.id}")
        expect(Rails.logger).to receive(:info)
          .with("Email notification would be sent for analysis ##{analysis.id}")
        expect(Rails.logger).to receive(:info)
          .with("Completed escalation notification for analysis ##{analysis.id}")
        expect(ActionCable.server).to receive(:broadcast)

        worker.perform(analysis.id, 'all')
      end
    end

    context 'エスカレーション処理' do
      it '分析をエスカレーション済みとしてマークする' do
        # analysisインスタンスを直接使わず、モックを作成
        allow(Analysis).to receive(:find).with(analysis.id).and_return(analysis)
        allow(analysis).to receive(:requires_escalation?).and_return(true)
        allow(analysis).to receive(:escalated?).and_return(false)
        expect(analysis).to receive(:escalate!)
        
        expect(Rails.logger).to receive(:info).at_least(:once)
        expect(ActionCable.server).to receive(:broadcast)

        worker.perform(analysis.id)
      end

      it '既にエスカレーション済みの場合はスキップする' do
        analysis.update!(escalated: true)
        
        allow(Analysis).to receive(:find).with(analysis.id).and_return(analysis)
        allow(analysis).to receive(:requires_escalation?).and_return(true)
        allow(analysis).to receive(:escalated?).and_return(true)
        expect(analysis).not_to receive(:escalate!)
        
        expect(Rails.logger).to receive(:info).at_least(:once)
        expect(ActionCable.server).to receive(:broadcast)

        worker.perform(analysis.id)
      end
    end

    context 'エラーハンドリング' do
      context '分析が見つからない場合' do
        it 'エラーをログに記録してリトライしない' do
          expect(Rails.logger).to receive(:error).with(/Analysis not found/)

          # エラーを発生させない（リトライしない）
          expect { worker.perform(999_999) }.not_to raise_error
        end
      end

      context 'その他のエラーの場合' do
        before do
          allow(Analysis).to receive(:find).with(analysis.id).and_raise(StandardError, 'Unexpected error')
        end

        it 'エラーをログに記録してリトライする' do
          expect(Rails.logger).to receive(:info)
            .with("Processing escalation notification for analysis ##{analysis.id}")
          expect(Rails.logger).to receive(:error).at_least(:once)

          expect do
            worker.perform(analysis.id)
          end.to raise_error(StandardError)
        end
      end
    end
  end

  describe 'Slackメッセージの構築' do
    it '適切な優先度カラーを返す' do
      colors = {
        'urgent' => 'danger',
        'high' => 'warning',
        'medium' => '#36a64f',
        'low' => 'good'
      }

      colors.each do |priority, expected_color|
        analysis.priority_level = priority
        message = worker.send(:build_slack_message, analysis)
        
        expect(message[:attachments].first[:color]).to eq(expected_color)
      end
    end
  end

  describe 'Sidekiqテスト' do
    before { Sidekiq::Testing.fake! }
    after { Sidekiq::Worker.clear_all }

    it 'ジョブをキューに追加できる' do
      expect do
        described_class.perform_async(analysis.id)
      end.to change(described_class.jobs, :size).by(1)
    end

    it '正しい引数でジョブが作成される' do
      described_class.perform_async(analysis.id, 'email')

      job = described_class.jobs.last
      expect(job['args']).to eq([analysis.id, 'email'])
    end
  end
end