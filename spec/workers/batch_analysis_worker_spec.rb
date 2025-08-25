# frozen_string_literal: true

require 'rails_helper'
require 'sidekiq/testing'

RSpec.describe BatchAnalysisWorker, type: :worker do
  let(:conversations) { create_list(:conversation, 3) }
  let(:conversation_ids) { conversations.map(&:id) }
  let(:worker) { described_class.new }

  describe 'Sidekiq設定' do
    it '低優先度キューを使用する' do
      expect(described_class.get_sidekiq_options['queue']).to eq('low')
    end

    it '適切なリトライ設定を持つ' do
      expect(described_class.get_sidekiq_options['retry']).to eq(3)
    end
  end

  describe '#perform' do
    before { Sidekiq::Testing.fake! }
    after { Sidekiq::Worker.clear_all }

    it '各会話に対して個別の分析ワーカーをキューイングする' do
      expect do
        worker.perform(conversation_ids)
      end.to change(ConversationAnalysisWorker.jobs, :size).by(3)
    end

    it '正しい引数で分析ワーカーを呼び出す' do
      options = { 'use_storage' => true }
      worker.perform(conversation_ids, options)

      ConversationAnalysisWorker.jobs.each do |job|
        expect(conversation_ids).to include(job['args'][0])
        expect(job['args'][1]).to eq(options)
      end
    end

    it '処理結果を返す' do
      result = worker.perform(conversation_ids)

      expect(result).to include(
        total: 3,
        queued: 3,
        failed: []
      )
    end

    context 'エラーが発生した場合' do
      it '失敗した会話IDを記録する' do
        # 最初のIDで例外を発生させ、残りは成功させる
        allow(ConversationAnalysisWorker).to receive(:perform_async) do |id, _|
          if id == conversations.first.id
            raise StandardError, 'Queue error'
          else
            true
          end
        end
        
        expect(Rails.logger).to receive(:info)
          .with("Starting batch analysis for #{conversation_ids.size} conversations")
        expect(Rails.logger).to receive(:error)
          .with("Failed to queue analysis for conversation ##{conversations.first.id}: Queue error")
        expect(Rails.logger).to receive(:info)
          .with("Batch analysis queued: 2 successful, 1 failed")
        
        result = worker.perform(conversation_ids)

        expect(result[:failed]).to include(conversations.first.id)
        expect(result[:queued]).to eq(2)
      end

      it 'エラーをログに記録する' do
        allow(ConversationAnalysisWorker).to receive(:perform_async) do |id, _|
          if id == conversations.first.id
            raise StandardError, 'Queue error'
          else
            true
          end
        end
        
        expect(Rails.logger).to receive(:info)
          .with("Starting batch analysis for #{conversation_ids.size} conversations")
        expect(Rails.logger).to receive(:error)
          .with("Failed to queue analysis for conversation ##{conversations.first.id}: Queue error")
        expect(Rails.logger).to receive(:info)
          .with("Batch analysis queued: 2 successful, 1 failed")

        worker.perform(conversation_ids)
      end
    end
  end

  describe 'バッチ処理のログ' do
    it '処理開始をログに記録する' do
      expect(Rails.logger).to receive(:info)
        .with("Starting batch analysis for #{conversation_ids.size} conversations")
      expect(Rails.logger).to receive(:info)
        .with(/Batch analysis queued: \d+ successful, \d+ failed/)

      worker.perform(conversation_ids)
    end

    it '処理結果をログに記録する' do
      expect(Rails.logger).to receive(:info)
        .with("Starting batch analysis for #{conversation_ids.size} conversations")
      expect(Rails.logger).to receive(:info)
        .with(/Batch analysis queued: \d+ successful, \d+ failed/)

      worker.perform(conversation_ids)
    end
  end
end