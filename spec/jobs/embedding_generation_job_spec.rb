# frozen_string_literal: true

require 'rails_helper'

RSpec.describe EmbeddingGenerationJob, type: :job do
  let(:conversation) { create(:conversation) }
  let(:message) { create(:message, conversation: conversation, content: 'テストメッセージです。') }
  
  describe '#perform' do
    context 'メッセージが存在する場合' do
      it 'embeddingを生成する' do
        expect_any_instance_of(VectorSearchService).to receive(:store_message_embedding)
                                                         .with(message)
                                                         .and_return(true)
        
        described_class.perform_now(message.id)
        
        message.reload
        expect(message.metadata['embedding_generated_at']).to be_present
      end

      it 'VectorSearchServiceを呼び出す' do
        vector_service = instance_double(VectorSearchService)
        allow(VectorSearchService).to receive(:new).and_return(vector_service)
        
        expect(vector_service).to receive(:store_message_embedding).with(message).and_return(true)
        
        described_class.perform_now(message.id)
      end

      it 'embedding生成が成功した場合、メタデータを更新する' do
        expect_any_instance_of(VectorSearchService).to receive(:store_message_embedding)
                                                         .and_return(true)
        
        described_class.perform_now(message.id)
        
        message.reload
        expect(message.metadata['embedding_generated_at']).to be_present
      end
    end

    context 'メッセージが存在しない場合' do
      it 'エラーを発生させずに処理を完了する' do
        non_existent_id = 99999
        
        expect { described_class.perform_now(non_existent_id) }
          .not_to raise_error
      end

      it 'ログを出力する' do
        non_existent_id = 99999
        
        expect(Rails.logger).to receive(:warn)
          .with("Message with ID #{non_existent_id} not found for embedding generation")
        
        described_class.perform_now(non_existent_id)
      end
    end

    context 'メッセージが既にembeddingを持っている場合' do
      before do
        message.update!(embedding: Array.new(1536, 0.1))
      end

      it 'embedding生成をスキップする' do
        expect_any_instance_of(VectorSearchService).not_to receive(:store_message_embedding)
        
        described_class.perform_now(message.id)
      end

      it 'スキップして処理を完了する' do
        expect { described_class.perform_now(message.id) }.not_to raise_error
      end
    end

    context 'embedding生成に失敗した場合' do
      it 'StandardErrorを発生させる' do
        # embeddingを削除してからテスト
        message.update_column(:embedding, nil)
        
        expect_any_instance_of(VectorSearchService).to receive(:store_message_embedding)
                                                         .and_return(false)
        
        expect { described_class.perform_now(message.id) }
          .to raise_error(StandardError, "Embedding generation failed for message #{message.id}")
      end

      it 'エラーログを出力する' do
        # embeddingを削除してからテスト
        message.update_column(:embedding, nil)
        
        expect_any_instance_of(VectorSearchService).to receive(:store_message_embedding)
                                                         .and_return(false)
        
        expect(Rails.logger).to receive(:error)
          .with("Failed to generate embedding for message #{message.id}")
        
        expect { described_class.perform_now(message.id) }
          .to raise_error(StandardError)
      end
    end

    context 'VectorSearchServiceでエラーが発生した場合' do
      let(:error_message) { 'OpenAI API Error' }

      it 'エラーを再発生させる（リトライのため）' do
        # embeddingを削除してからテスト
        message.update_column(:embedding, nil)
        
        expect_any_instance_of(VectorSearchService).to receive(:store_message_embedding)
                                                         .and_raise(StandardError.new(error_message))
        
        expect { described_class.perform_now(message.id) }
          .to raise_error(StandardError, error_message)
      end

      it 'エラーログを出力する' do
        # embeddingを削除してからテスト
        message.update_column(:embedding, nil)
        
        expect_any_instance_of(VectorSearchService).to receive(:store_message_embedding)
                                                         .and_raise(StandardError.new(error_message))
        
        expect(Rails.logger).to receive(:error)
          .with("Embedding generation error for message #{message.id}: #{error_message}")
        
        expect { described_class.perform_now(message.id) }
          .to raise_error(StandardError)
      end
    end
  end

  describe 'ジョブキュー' do
    it 'defaultキューを使用する' do
      expect(described_class.queue_name).to eq('default')
    end
  end

  describe 'リトライ設定' do
    it 'ApplicationJobを継承している' do
      expect(described_class.superclass).to eq(ApplicationJob)
    end
  end

  describe 'パフォーマンス' do
    it '適切な時間内で処理が完了する' do
      expect_any_instance_of(VectorSearchService).to receive(:store_message_embedding)
                                                       .and_return(true)
      
      start_time = Time.current
      described_class.perform_now(message.id)
      end_time = Time.current
      
      # テスト環境では1秒以内に完了する想定
      expect(end_time - start_time).to be < 1.0
    end
  end

  describe 'ログ記録' do
    it '正常に実行される' do
      # embeddingを削除してからテスト
      message.update_column(:embedding, nil)
      
      expect_any_instance_of(VectorSearchService).to receive(:store_message_embedding)
                                                       .and_return(true)
      
      expect { described_class.perform_now(message.id) }.not_to raise_error
    end
  end
end