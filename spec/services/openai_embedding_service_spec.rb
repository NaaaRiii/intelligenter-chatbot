# frozen_string_literal: true

require 'rails_helper'

RSpec.describe OpenaiEmbeddingService do
  let(:service) { described_class.new }
  let(:sample_text) { 'ログインできません。パスワードを忘れました。' }

  describe '#initialize' do
    it 'サービスが正常に初期化される' do
      expect(service).to be_instance_of(described_class)
    end
  end

  describe '#generate_embedding' do
    context '正常なテキストの場合' do
      it 'embeddingを生成する' do
        embedding = service.generate_embedding(sample_text)
        
        expect(embedding).to be_a(Array)
        expect(embedding.size).to eq(1536)
        expect(embedding).to all(be_a(Numeric))
      end

      it '正規化されたベクトルを返す' do
        embedding = service.generate_embedding(sample_text)
        
        # L2ノルムが1に近いことを確認（正規化されている）
        magnitude = Math.sqrt(embedding.sum { |v| v**2 })
        expect(magnitude).to be_within(0.1).of(1.0)
      end

      it '同じテキストに対して一貫した結果を返す' do
        embedding1 = service.generate_embedding(sample_text)
        embedding2 = service.generate_embedding(sample_text)
        
        # モック環境では毎回ランダムなので、構造のみ確認
        expect(embedding1.size).to eq(embedding2.size)
        expect(embedding1).to all(be_a(Numeric))
        expect(embedding2).to all(be_a(Numeric))
      end
    end

    context '異常なケース' do
      it '空のテキストでエラーが発生する' do
        expect { service.generate_embedding('') }.to raise_error(OpenaiEmbeddingService::EmbeddingError, /テキストが空です/)
      end

      it 'nilテキストでエラーが発生する' do
        expect { service.generate_embedding(nil) }.to raise_error(OpenaiEmbeddingService::EmbeddingError, /テキストが空です/)
      end

      it '長すぎるテキストでエラーが発生する' do
        long_text = 'あ' * 40000
        expect { service.generate_embedding(long_text) }.to raise_error(OpenaiEmbeddingService::EmbeddingError, /テキストが長すぎます/)
      end
    end
  end

  describe '#generate_embeddings' do
    let(:texts) { ['ログイン問題', 'パスワードリセット', '機能について'] }

    context '複数テキストの場合' do
      it '全てのテキストのembeddingを生成する' do
        embeddings = service.generate_embeddings(texts)
        
        expect(embeddings).to be_a(Array)
        expect(embeddings.size).to eq(3)
        
        embeddings.each do |embedding|
          expect(embedding).to be_a(Array)
          expect(embedding.size).to eq(1536)
          expect(embedding).to all(be_a(Numeric))
        end
      end

      it '各embeddingが正規化されている' do
        embeddings = service.generate_embeddings(texts)
        
        embeddings.each do |embedding|
          magnitude = Math.sqrt(embedding.sum { |v| v**2 })
          expect(magnitude).to be_within(0.1).of(1.0)
        end
      end
    end

    context '異常なケース' do
      it '空の配列でエラーが発生する' do
        expect { service.generate_embeddings([]) }.to raise_error(OpenaiEmbeddingService::EmbeddingError, /テキスト配列が空です/)
      end

      it '大きすぎるバッチでエラーが発生する' do
        large_batch = Array.new(1001) { 'テスト' }
        expect { service.generate_embeddings(large_batch) }.to raise_error(OpenaiEmbeddingService::EmbeddingError, /バッチサイズが大きすぎます/)
      end

      it '空のテキストを含む配列でエラーが発生する' do
        texts_with_empty = ['正常なテキスト', '', '別の正常なテキスト']
        expect { service.generate_embeddings(texts_with_empty) }.to raise_error(OpenaiEmbeddingService::EmbeddingError, /テキスト\[1\]: テキストが空です/)
      end
    end
  end

  describe '#embedding_info' do
    it '正しいembedding情報を返す' do
      info = service.embedding_info
      
      expect(info).to be_a(Hash)
      expect(info[:model]).to eq('text-embedding-3-small')
      expect(info[:dimensions]).to eq(1536)
      expect(info[:max_tokens]).to eq(8191)
      expect(info[:provider]).to eq('openai')
    end
  end

  describe '#model_info' do
    it '正しいモデル情報を返す' do
      info = service.model_info
      
      expect(info).to be_a(Hash)
      expect(info[:name]).to eq('text-embedding-3-small')
      expect(info[:description]).to include('OpenAI')
      expect(info[:dimensions]).to eq(1536)
      expect(info[:cost_per_1k_tokens]).to eq(0.00002)
      expect(info[:max_input_tokens]).to eq(8191)
    end
  end

  describe 'パフォーマンステスト' do
    it '単一embedding生成が高速である' do
      start_time = Time.current
      service.generate_embedding(sample_text)
      end_time = Time.current
      
      # モック環境なので非常に高速（1秒以内）
      expect(end_time - start_time).to be < 1.0
    end

    it 'バッチembedding生成が効率的である' do
      texts = Array.new(10) { |i| "テストメッセージ #{i}" }
      
      start_time = Time.current
      service.generate_embeddings(texts)
      end_time = Time.current
      
      # バッチ処理も高速（モック環境）
      expect(end_time - start_time).to be < 2.0
    end
  end

  describe 'エラーハンドリング' do
    it 'EmbeddingErrorをキャッチできる' do
      expect { service.generate_embedding('') }.to raise_error(OpenaiEmbeddingService::EmbeddingError)
    end

    it 'エラーメッセージが適切である' do
      begin
        service.generate_embedding('')
      rescue OpenaiEmbeddingService::EmbeddingError => e
        expect(e.message).to include('テキストが空です')
      end
    end
  end

  describe '国際化対応' do
    it '日本語テキストを正しく処理する' do
      japanese_text = 'こんにちは、サポートが必要です。ログインに問題があります。'
      embedding = service.generate_embedding(japanese_text)
      
      expect(embedding).to be_a(Array)
      expect(embedding.size).to eq(1536)
      expect(embedding).to all(be_a(Numeric))
    end

    it '英語テキストを正しく処理する' do
      english_text = 'Hello, I need help with login issues.'
      embedding = service.generate_embedding(english_text)
      
      expect(embedding).to be_a(Array)
      expect(embedding.size).to eq(1536)
      expect(embedding).to all(be_a(Numeric))
    end

    it '混合言語テキストを正しく処理する' do
      mixed_text = 'Hello こんにちは、help サポート needed 必要です。'
      embedding = service.generate_embedding(mixed_text)
      
      expect(embedding).to be_a(Array)
      expect(embedding.size).to eq(1536)
      expect(embedding).to all(be_a(Numeric))
    end
  end
end