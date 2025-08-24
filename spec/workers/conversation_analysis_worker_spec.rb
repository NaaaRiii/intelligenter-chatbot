# frozen_string_literal: true

require 'rails_helper'
require 'sidekiq/testing'

RSpec.describe ConversationAnalysisWorker, type: :worker do
  let(:conversation) { create(:conversation) }
  let(:worker) { described_class.new }

  before do
    # メッセージを作成
    create(:message, conversation: conversation, role: 'user', content: 'システムが遅いです')
    create(:message, conversation: conversation, role: 'assistant', content: 'お困りですね')
  end

  describe 'Sidekiq設定' do
    it '正しいキューを使用する' do
      expect(described_class.get_sidekiq_options['queue']).to eq('analysis')
    end

    it '適切なリトライ設定を持つ' do
      expect(described_class.get_sidekiq_options['retry']).to eq(5)
    end

    it 'デッドジョブを保存する設定' do
      expect(described_class.get_sidekiq_options['dead']).to be true
    end
  end

  describe '#perform' do
    context 'ストレージサービスを使用する場合' do
      it '分析を実行して結果を保存する' do
        expect_any_instance_of(AnalysisStorageService).to receive(:store_analysis)
          .and_return(build(:analysis))

        worker.perform(conversation.id, 'use_storage' => true)
      end
    end

    context '通常の分析の場合' do
      it 'SentimentAnalyzerを使用する' do
        expect_any_instance_of(SentimentAnalyzer).to receive(:analyze_conversation)
          .and_return(overall_sentiment: 'negative')

        worker.perform(conversation.id, 'use_storage' => false)
      end
    end

    context '分析完了後' do
      before do
        allow_any_instance_of(SentimentAnalyzer).to receive(:analyze_conversation)
          .and_return(overall_sentiment: 'positive')
      end

      it 'ActionCableでブロードキャストする' do
        expect(ActionCable.server).to receive(:broadcast).with(
          "conversation_#{conversation.id}",
          hash_including(type: 'analysis_complete')
        )

        worker.perform(conversation.id)
      end
    end

    context 'エラーが発生した場合' do
      context '会話が見つからない場合' do
        it 'ActiveRecord::RecordNotFoundを発生させる' do
          expect do
            worker.perform(999_999)
          end.to raise_error(ActiveRecord::RecordNotFound)
        end
      end

      context '分析中にエラーが発生した場合' do
        before do
          allow_any_instance_of(SentimentAnalyzer).to receive(:analyze_conversation)
            .and_raise(StandardError, 'Analysis failed')
        end

        it 'エラーをログに記録する' do
          expect(Rails.logger).to receive(:error).at_least(:once)

          expect do
            worker.perform(conversation.id)
          end.to raise_error(StandardError)
        end

        it 'エラー通知をブロードキャストする' do
          expect(ActionCable.server).to receive(:broadcast).with(
            "conversation_#{conversation.id}",
            hash_including(type: 'analysis_error')
          )

          expect do
            worker.perform(conversation.id)
          end.to raise_error(StandardError)
        end
      end
    end
  end

  describe 'Sidekiqテスト' do
    before { Sidekiq::Testing.fake! }
    after { Sidekiq::Worker.clear_all }

    it 'ジョブをキューに追加できる' do
      expect do
        described_class.perform_async(conversation.id)
      end.to change(described_class.jobs, :size).by(1)
    end

    it '正しい引数でジョブが作成される' do
      described_class.perform_async(conversation.id, 'use_storage' => true)

      job = described_class.jobs.last
      expect(job['args']).to eq([conversation.id, { 'use_storage' => true }])
    end

    context 'インライン実行' do
      before { Sidekiq::Testing.inline! }

      it '即座にジョブを実行する' do
        expect_any_instance_of(SentimentAnalyzer).to receive(:analyze_conversation)
          .and_return(overall_sentiment: 'positive')

        described_class.perform_async(conversation.id)
      end
    end
  end

  describe 'リトライ設定' do
    it 'タイムアウトエラーの場合は長めの待機時間' do
      retry_in = described_class.sidekiq_retry_in_block

      # 3回目のリトライ
      wait_time = retry_in.call(3, Net::ReadTimeout.new)
      expect(wait_time).to eq(270) # 3^2 * 30
    end

    it '通常のエラーの場合は標準の待機時間' do
      retry_in = described_class.sidekiq_retry_in_block

      # 3回目のリトライ
      wait_time = retry_in.call(3, StandardError.new)
      expect(wait_time).to eq(90) # 3^2 * 10
    end
  end
end