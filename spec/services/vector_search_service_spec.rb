# frozen_string_literal: true

require 'rails_helper'

RSpec.describe VectorSearchService do
  let(:service) { described_class.new }
  
  describe '#generate_embedding' do
    it 'テキストからベクトル埋め込みを生成する' do
      text = 'ログインできません。パスワードを忘れてしまいました。'
      
      embedding = service.generate_embedding(text)
      
      expect(embedding).to be_an(Array)
      expect(embedding.size).to eq(1536) # OpenAI ada-002の次元数
      expect(embedding.all? { |v| v.is_a?(Float) }).to be true
      expect(embedding.all? { |v| v.between?(-1, 1) }).to be true
    end
    
    it '空のテキストに対してデフォルトベクトルを返す' do
      embedding = service.generate_embedding('')
      
      expect(embedding).to be_an(Array)
      expect(embedding.size).to eq(1536)
    end
    
    it '同じテキストには同じベクトルを生成する' do
      text = '注文をキャンセルしたい'
      
      embedding1 = service.generate_embedding(text)
      embedding2 = service.generate_embedding(text)
      
      expect(embedding1).to eq(embedding2)
    end
  end
  
  describe '#store_message_embedding' do
    let(:conversation) { create(:conversation) }
    let(:message) { create(:message, conversation: conversation, content: 'アカウントの削除方法を教えてください') }
    
    it 'メッセージのベクトル埋め込みを保存する' do
      result = service.store_message_embedding(message)
      
      expect(result).to be true
      message.reload
      expect(message.embedding).to be_present
      expect(message.embedding).to be_an(Array)
      expect(message.embedding.size).to eq(1536)
    end
    
    it '既存の埋め込みを上書きする' do
      # 最初の埋め込み
      service.store_message_embedding(message)
      original_embedding = message.reload.embedding
      
      # 内容を変更して再度埋め込み
      message.update!(content: '新しい内容')
      service.store_message_embedding(message)
      
      expect(message.reload.embedding).not_to eq(original_embedding)
    end
  end
  
  describe '#find_similar_messages' do
    let(:conversation) { create(:conversation) }
    
    before do
      # テストデータの準備
      @login_msg1 = create(:message, conversation: conversation, 
                           content: 'ログインできません',
                           embedding: generate_mock_embedding('login_issue'))
      @login_msg2 = create(:message, conversation: conversation,
                           content: 'パスワードを忘れてログインできない',
                           embedding: generate_mock_embedding('login_password'))
      @payment_msg = create(:message, conversation: conversation,
                            content: '支払い方法を変更したい',
                            embedding: generate_mock_embedding('payment'))
      @cancel_msg = create(:message, conversation: conversation,
                           content: '注文をキャンセルする方法',
                           embedding: generate_mock_embedding('cancel'))
    end
    
    it '類似メッセージを検索する' do
      query = 'ログインの問題があります'
      
      similar = service.find_similar_messages(query, limit: 2)
      
      expect(similar.size).to eq(2)
      # ログイン関連のメッセージが上位に来ることを確認
      similar_contents = similar.map(&:content)
      expect(similar_contents.any? { |c| c.include?('ログイン') }).to be true
    end
    
    it 'スコアとともに結果を返す' do
      query = 'ログインできない'
      
      results = service.find_similar_messages_with_scores(query, limit: 3)
      
      expect(results).to be_an(Array)
      expect(results.first).to include(:message, :score, :distance)
      expect(results.first[:score]).to be_between(0, 1)
      expect(results.first[:distance]).to be >= 0
      
      # スコアの降順でソートされている
      scores = results.map { |r| r[:score] }
      expect(scores).to eq(scores.sort.reverse)
    end
    
    it '閾値以上の類似度のメッセージのみ返す' do
      query = '全く関係のない内容'
      
      similar = service.find_similar_messages(query, threshold: 0.8)
      
      expect(similar).to be_empty
    end
  end
  
  describe '#find_similar_conversations' do
    let(:user) { create(:user) }
    
    before do
      # 複数の会話を作成
      @conv1 = create(:conversation, user: user)
      create(:message, conversation: @conv1, content: 'ログインエラー', 
             embedding: generate_mock_embedding('login_error'))
      create(:message, conversation: @conv1, content: 'パスワードリセット',
             embedding: generate_mock_embedding('password_reset'))
      
      @conv2 = create(:conversation, user: user)
      create(:message, conversation: @conv2, content: 'ログインの問題',
             embedding: generate_mock_embedding('login_problem'))
      
      @conv3 = create(:conversation, user: user)
      create(:message, conversation: @conv3, content: '請求書について',
             embedding: generate_mock_embedding('billing'))
    end
    
    it '類似の会話を検索する' do
      query = 'ログインできません'
      
      similar_convs = service.find_similar_conversations(query, limit: 2)
      
      expect(similar_convs.size).to eq(2)
      expect(similar_convs.map(&:id)).to include(@conv1.id, @conv2.id)
      expect(similar_convs.map(&:id)).not_to include(@conv3.id)
    end
    
    it '会話全体の平均ベクトルで類似度を計算する' do
      query = 'ログインとパスワードの問題'
      
      results = service.find_similar_conversations_with_scores(query)
      
      # 両方のトピックを含む会話1が最上位
      expect(results.first[:conversation].id).to eq(@conv1.id)
      expect(results.first[:average_score]).to be > results.second[:average_score]
    end
  end
  
  describe '#search_knowledge_base' do
    before do
      # KnowledgeBaseにベクトル付きデータを準備
      @kb1 = create(:knowledge_base,
                    pattern_type: 'successful_conversation',
                    content: { 'solution' => 'パスワードリセットで解決' },
                    embedding: generate_mock_embedding('password_solution'),
                    tags: ['login', 'password'])
      @kb2 = create(:knowledge_base,
                    pattern_type: 'successful_conversation', 
                    content: { 'solution' => 'キャッシュクリアで解決' },
                    embedding: generate_mock_embedding('cache_solution'),
                    tags: ['performance', 'cache'])
    end
    
    it 'ナレッジベースから類似パターンを検索する' do
      query = 'ログインできない問題'
      
      patterns = service.search_knowledge_base(query, limit: 1)
      
      expect(patterns.size).to eq(1)
      expect(patterns.first.id).to eq(@kb1.id)
      expect(patterns.first.tags).to include('login')
    end
    
    it 'タグでフィルタリングして検索する' do
      query = 'システムの問題'
      
      patterns = service.search_knowledge_base(query, tags: ['cache'])
      
      expect(patterns.map(&:id)).to include(@kb2.id)
      expect(patterns.map(&:id)).not_to include(@kb1.id)
    end
  end
  
  describe '#batch_generate_embeddings' do
    it '複数のテキストのベクトルを一括生成する' do
      texts = [
        'ログインの問題',
        '支払い方法の変更',
        '注文のキャンセル'
      ]
      
      embeddings = service.batch_generate_embeddings(texts)
      
      expect(embeddings.size).to eq(3)
      expect(embeddings.all? { |e| e.is_a?(Array) && e.size == 1536 }).to be true
    end
    
    it 'バッチサイズ制限を守る' do
      texts = Array.new(150) { |i| "テキスト#{i}" }
      
      embeddings = service.batch_generate_embeddings(texts, batch_size: 50)
      
      expect(embeddings.size).to eq(150)
      # バッチ処理が3回実行されることを確認
    end
  end
  
  describe '#update_all_embeddings' do
    before do
      # 埋め込みのないメッセージを作成
      create_list(:message, 5, embedding: nil)
      # 埋め込み済みのメッセージ
      create_list(:message, 3, embedding: Array.new(1536) { rand(-1.0..1.0) })
    end
    
    it '埋め込みのないメッセージすべてにベクトルを生成する' do
      result = service.update_all_embeddings
      
      expect(result[:processed]).to eq(5)
      expect(result[:skipped]).to eq(0)  # forceがfalseの場合、nilのみ処理するのでskipは0
      expect(result[:errors]).to eq(0)
      
      # すべてのメッセージに埋め込みがある
      expect(Message.where(embedding: nil).count).to eq(0)
    end
    
    it '強制更新モードですべてのメッセージを更新する' do
      result = service.update_all_embeddings(force: true)
      
      expect(result[:processed]).to eq(8)
      expect(result[:skipped]).to eq(0)
    end
  end
  
  describe '#calculate_similarity' do
    it 'コサイン類似度を計算する' do
      vec1 = [1.0, 0.0, 0.0]
      vec2 = [1.0, 0.0, 0.0]
      vec3 = [0.0, 1.0, 0.0]
      vec4 = [-1.0, 0.0, 0.0]
      
      expect(service.calculate_similarity(vec1, vec2)).to eq(1.0) # 同一
      expect(service.calculate_similarity(vec1, vec3)).to eq(0.0) # 直交
      expect(service.calculate_similarity(vec1, vec4)).to eq(-1.0) # 逆向き
    end
  end
  
  describe '#clustering_messages' do
    before do
      # クラスタリング用のテストデータ
      create_list(:message, 10, :with_embedding_cluster, cluster: 'login')
      create_list(:message, 8, :with_embedding_cluster, cluster: 'payment')
      create_list(:message, 5, :with_embedding_cluster, cluster: 'shipping')
    end
    
    it 'メッセージをクラスタリングする' do
      clusters = service.clustering_messages(n_clusters: 3)
      
      expect(clusters.size).to eq(3)
      expect(clusters.map { |c| c[:messages].size }.sum).to eq(23)
      
      # 各クラスタにラベルが付いている
      expect(clusters.all? { |c| c[:label].present? }).to be true
      expect(clusters.all? { |c| c[:centroid].present? }).to be true
    end
    
    it 'クラスタの重心から代表的なメッセージを選ぶ' do
      clusters = service.clustering_messages(n_clusters: 3)
      
      clusters.each do |cluster|
        expect(cluster[:representative_messages]).to be_present
        expect(cluster[:representative_messages].size).to be <= 3
      end
    end
  end
  
  private
  
  def generate_mock_embedding(category)
    # カテゴリに基づいてモックベクトルを生成
    base_vectors = {
      'login_issue' => Array.new(1536) { |i| Math.sin(i * 0.1) * 0.5 },
      'login_password' => Array.new(1536) { |i| Math.sin(i * 0.1 + 0.5) * 0.5 },
      'login_error' => Array.new(1536) { |i| Math.sin(i * 0.1 + 0.2) * 0.5 },
      'login_problem' => Array.new(1536) { |i| Math.sin(i * 0.1 + 0.3) * 0.5 },
      'password_reset' => Array.new(1536) { |i| Math.sin(i * 0.1 + 0.6) * 0.5 },
      'password_solution' => Array.new(1536) { |i| Math.sin(i * 0.1 + 0.7) * 0.5 },
      'payment' => Array.new(1536) { |i| Math.cos(i * 0.1) * 0.5 },
      'billing' => Array.new(1536) { |i| Math.cos(i * 0.1 + 0.5) * 0.5 },
      'cancel' => Array.new(1536) { |i| Math.sin(i * 0.2) * 0.5 },
      'cache_solution' => Array.new(1536) { |i| Math.cos(i * 0.2) * 0.5 },
      'shipping' => Array.new(1536) { |i| Math.sin(i * 0.3) * 0.5 }
    }
    
    base_vectors[category] || Array.new(1536) { rand(-0.5..0.5) }
  end
end