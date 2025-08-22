# frozen_string_literal: true

require 'rails_helper'

RSpec.describe MessageBatchService, type: :service do
  let(:conversation) { create(:conversation) }
  
  before do
    ActiveJob::Base.queue_adapter = :test
  end
  
  describe '#save_batch' do
    context '正常なデータの場合' do
      let(:messages_data) do
        [
          { content: 'Message 1', role: 'user', metadata: { test: true } },
          { content: 'Message 2', role: 'assistant' },
          { content: 'Message 3', role: 'user' }
        ]
      end

      it 'メッセージをバッチで保存する' do
        service = described_class.new(
          conversation: conversation,
          messages_data: messages_data
        )

        expect { service.save_batch }.to change(Message, :count).by(3)
      end

      it 'skip_callbacksがtrueの場合、高速に保存する' do
        service = described_class.new(
          conversation: conversation,
          messages_data: messages_data,
          skip_callbacks: true
        )

        expect(Message).not_to receive(:create!)
        expect { service.save_batch }.to change(Message, :count).by(3)
      end

      it '会話のタイムスタンプを更新する' do
        service = described_class.new(
          conversation: conversation,
          messages_data: messages_data,
          skip_callbacks: true
        )

        expect { service.save_batch }.to change { conversation.reload.updated_at }
      end
    end

    context '無効なデータの場合' do
      let(:invalid_messages_data) do
        [
          { content: '', role: 'user' }, # 空のコンテンツ
          { content: 'Valid', role: 'invalid_role' } # 無効なロール
        ]
      end

      it 'エラーを返す' do
        service = described_class.new(
          conversation: conversation,
          messages_data: invalid_messages_data
        )

        expect(service.save_batch).to be false
        expect(service.errors).not_to be_empty
      end

      it 'トランザクションでロールバックする' do
        service = described_class.new(
          conversation: conversation,
          messages_data: invalid_messages_data
        )

        expect { service.save_batch }.not_to change(Message, :count)
      end
    end

    context 'バッチサイズの制限' do
      let(:large_messages_data) do
        101.times.map { |i| { content: "Message #{i}", role: 'user' } }
      end

      it 'MAX_BATCH_SIZEを超える場合はエラー' do
        service = described_class.new(
          conversation: conversation,
          messages_data: large_messages_data
        )

        expect(service.save_batch).to be false
        expect(Message.count).to eq(0)
      end
    end
  end

  describe '#save_batch_async' do
    let(:messages_data) do
      [
        { content: 'Async message 1', role: 'user' },
        { content: 'Async message 2', role: 'assistant' }
      ]
    end

    it '非同期ジョブをエンキューする' do
      service = described_class.new(
        conversation: conversation,
        messages_data: messages_data
      )

      expect do
        service.save_batch_async
      end.to have_enqueued_job(MessageBatchJob)
            .with(conversation_id: conversation.id, messages_data: messages_data)
    end

    it '無効なデータの場合はエンキューしない' do
      service = described_class.new(
        conversation: nil,
        messages_data: messages_data
      )

      expect { service.save_batch_async }.not_to have_enqueued_job(MessageBatchJob)
    end
  end

  describe '.stream_save' do
    let(:message_stream) do
      Enumerator.new do |yielder|
        100.times do |i|
          yielder << { content: "Stream message #{i}", role: i.even? ? 'user' : 'assistant' }
        end
      end
    end

    it 'ストリーミングでメッセージを保存する' do
      saved_count = described_class.stream_save(
        conversation: conversation,
        message_stream: message_stream,
        batch_size: 25
      )

      expect(saved_count).to eq(100)
      expect(conversation.messages.count).to eq(100)
    end

    it '指定されたバッチサイズで分割保存する' do
      expect(MessageBatchService).to receive(:new).exactly(4).times.and_call_original

      described_class.stream_save(
        conversation: conversation,
        message_stream: message_stream,
        batch_size: 25
      )
    end

    it 'エラー時は例外を発生させる' do
      error_stream = Enumerator.new do |yielder|
        yielder << { content: '', role: 'user' } # 無効なデータ
      end

      expect do
        described_class.stream_save(
          conversation: conversation,
          message_stream: error_stream,
          batch_size: 1
        )
      end.to raise_error(RuntimeError, /Failed to save batch/)
    end
  end
end