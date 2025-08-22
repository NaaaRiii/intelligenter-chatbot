# frozen_string_literal: true

require 'rails_helper'
require 'benchmark'

RSpec.describe 'Message Performance', type: :model do
  describe 'クエリパフォーマンス' do
    let(:conversation) { create(:conversation) }

    before do
      # テストデータを大量に作成
      100.times do |i|
        create(:message,
               conversation: conversation,
               content: "Message #{i}",
               role: i.even? ? 'user' : 'assistant',
               created_at: i.hours.ago)
      end
    end

    it 'インデックスを使用した高速検索' do
      time = Benchmark.realtime do
        Message.for_conversation(conversation.id)
               .chronological
               .limit(50)
               .to_a
      end

      expect(time).to be < 0.1 # 100ms以内
    end

    it '時系列取得が高速' do
      time = Benchmark.realtime do
        Message.for_conversation(conversation.id)
               .created_between(1.week.ago, Time.current)
               .chronological
               .to_a
      end

      expect(time).to be < 0.15 # 150ms以内
    end

    it 'ロール別フィルタリングが高速' do
      time = Benchmark.realtime do
        Message.for_conversation(conversation.id)
               .user_messages
               .latest_n(20)
               .to_a
      end

      expect(time).to be < 0.1 # 100ms以内
    end

    it 'ページネーションが効率的' do
      time = Benchmark.realtime do
        5.times do |page|
          Message.for_conversation(conversation.id)
                 .paginated(page + 1, 20)
                 .to_a
        end
      end

      expect(time).to be < 0.2 # 200ms以内（5ページ分）
    end
  end

  describe 'キャッシュパフォーマンス' do
    let(:conversation) { create(:conversation) }

    before do
      50.times { create(:message, conversation: conversation) }
      Rails.cache.clear
    end

    it 'キャッシュからの取得が高速' do
      # CIではtest環境がNullStoreのため、この例に限りMemoryStoreを使用
      memory_store = ActiveSupport::Cache::MemoryStore.new
      allow(Rails).to receive(:cache).and_return(memory_store)
      Rails.cache.clear

      # 初回（キャッシュなし）
      first_time = Benchmark.realtime do
        Message.cached_for_conversation(conversation.id, 30)
      end

      # 2回目（キャッシュあり）
      second_time = Benchmark.realtime do
        Message.cached_for_conversation(conversation.id, 30)
      end

      # 実行環境差でのばらつきを考慮し、2倍以上の高速化を期待
      expect(second_time).to be < (first_time * 0.5)
    end

    it 'キャッシュが正しく無効化される' do
      # キャッシュを作成
      cached_messages = Message.cached_for_conversation(conversation.id, 20)
      initial_count = cached_messages.size

      # 新しいメッセージを追加
      create(:message, conversation: conversation, content: 'New message')

      # キャッシュが更新されていることを確認
      updated_messages = Message.cached_for_conversation(conversation.id, 20)
      expect(updated_messages.size).to eq(initial_count) # limit=20なので同じ
      expect(updated_messages.map(&:content)).to include('New message')
    end
  end

  describe 'バッチ保存パフォーマンス' do
    let(:conversation) { create(:conversation) }

    it '大量メッセージの一括保存が高速' do
      messages_data = 100.times.map do |i|
        {
          content: "Batch message #{i}",
          role: i.even? ? 'user' : 'assistant',
          metadata: { index: i }
        }
      end

      time = Benchmark.realtime do
        service = MessageBatchService.new(
          conversation: conversation,
          messages_data: messages_data,
          skip_callbacks: true
        )
        service.save_batch
      end

      expect(time).to be < 0.5 # 500ms以内（100件）
      expect(conversation.messages.count).to eq(100)
    end

    it '個別保存よりバッチ保存が高速' do
      messages_data = 50.times.map do |i|
        { content: "Message #{i}", role: 'user' }
      end

      # 個別保存の時間
      individual_time = Benchmark.realtime do
        messages_data.each do |data|
          conversation.messages.create!(data)
        end
      end

      conversation.messages.destroy_all

      # バッチ保存の時間
      batch_time = Benchmark.realtime do
        service = MessageBatchService.new(
          conversation: conversation,
          messages_data: messages_data,
          skip_callbacks: true
        )
        service.save_batch
      end

      expect(batch_time).to be < (individual_time * 0.3) # 3倍以上高速
    end
  end

  describe 'N+1クエリの回避' do
    let(:conversations) { create_list(:conversation, 10) }

    before do
      conversations.each do |conv|
        create_list(:message, 5, conversation: conv)
      end
    end

    it 'includesでN+1を回避' do
      expect do
        messages = Message.with_conversation.limit(50)
        messages.each { |m| m.conversation.session_id }
      end.to make_database_queries(count: 2) # 2クエリのみ（messages + conversations）
    end

    it '複数の関連を効率的に取得' do
      expect do
        Message.includes(conversation: :user)
               .where(created_at: 1.day.ago..Time.current)
               .each do |message| # rubocop:disable Rails/FindEach
          message.conversation.user
          message.content
        end
      end.to make_database_queries(count: 3) # 3クエリのみ
    end
  end
end
