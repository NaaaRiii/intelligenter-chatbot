# frozen_string_literal: true

require 'rails_helper'

RSpec.describe RagService do
  let(:service) { described_class.new }
  let(:vector_service) { instance_double(VectorSearchService) }
  let(:semantic_service) { instance_double(SemanticSimilarityService) }
  
  before do
    allow(VectorSearchService).to receive(:new).and_return(vector_service)
    allow(SemanticSimilarityService).to receive(:new).and_return(semantic_service)
  end
  
  describe '#retrieve_context' do
    context '新規問い合わせに対する関連情報の取得' do
      let(:query) { 'ログインができません。パスワードを忘れました。' }
      let(:conversation) { create(:conversation) }
      
      before do
        # 過去の類似メッセージを準備
        @similar_msg1 = create(:message,
                              content: 'パスワードリセットの方法を教えてください',
                              metadata: { resolution: 'パスワードリセットリンクを送信' })
        @similar_msg2 = create(:message,
                              content: 'ログインエラーが発生しています',
                              metadata: { resolution: 'ブラウザキャッシュをクリア' })
        @similar_msg3 = create(:message,
                              content: 'アカウントにアクセスできません',
                              metadata: { resolution: '二段階認証の確認' })
        
        # モックの設定
        allow(vector_service).to receive(:find_similar_messages_with_scores)
          .with(query, limit: 3)
          .and_return([
            { message: @similar_msg1, score: 0.92, distance: 0.08 },
            { message: @similar_msg2, score: 0.85, distance: 0.15 },
            { message: @similar_msg3, score: 0.78, distance: 0.22 }
          ])
      end
      
      it '類似度の高い過去のメッセージを3件取得する' do
        context = service.retrieve_context(query, conversation: conversation)
        
        expect(context[:retrieved_messages].size).to eq(3)
        expect(context[:retrieved_messages].first[:message]).to eq(@similar_msg1)
        expect(context[:retrieved_messages].first[:score]).to eq(0.92)
      end
      
      it '取得したコンテキストを構造化して返す' do
        context = service.retrieve_context(query, conversation: conversation)
        
        expect(context).to include(
          :query,
          :retrieved_messages,
          :relevant_solutions,
          :context_summary
        )
        expect(context[:query]).to eq(query)
        expect(context[:relevant_solutions]).to be_an(Array)
        expect(context[:context_summary]).to be_present
      end
      
      it '解決策情報を抽出して含める' do
        context = service.retrieve_context(query, conversation: conversation)
        
        solutions = context[:relevant_solutions]
        expect(solutions).to include('パスワードリセットリンクを送信')
        expect(solutions).to include('ブラウザキャッシュをクリア')
        expect(solutions).to include('二段階認証の確認')
      end
      
      it '閾値未満の類似度のメッセージは除外する' do
        allow(vector_service).to receive(:find_similar_messages_with_scores)
          .with(query, limit: 3)
          .and_return([
            { message: @similar_msg1, score: 0.92, distance: 0.08 },
            { message: @similar_msg2, score: 0.65, distance: 0.35 } # 閾値未満
          ])
        
        context = service.retrieve_context(query, conversation: conversation)
        
        # 閾値（0.7）を超えるもののみ返される
        expect(context[:retrieved_messages].size).to eq(1)
      end
    end
  end
  
  describe '#augment_query' do
    context 'クエリの拡張と強化' do
      let(:query) { 'ログインできない' }
      let(:context) do
        {
          retrieved_messages: [
            { message: create(:message, content: 'パスワードを忘れた'), score: 0.9 },
            { message: create(:message, content: 'アカウントロック'), score: 0.8 }
          ],
          relevant_solutions: ['パスワードリセット', 'アカウント復旧']
        }
      end
      
      it 'コンテキストを使用してクエリを拡張する' do
        augmented = service.augment_query(query, context)
        
        expect(augmented[:original_query]).to eq(query)
        expect(augmented[:augmented_query]).to be_present
        expect(augmented[:augmented_query].length).to be > query.length
        expect(augmented[:context_used]).to be true
      end
      
      it '関連キーワードを抽出して追加する' do
        augmented = service.augment_query(query, context)
        
        expect(augmented[:keywords]).to be_an(Array)
        expect(augmented[:keywords]).to include('ログイン')
        expect(augmented[:keywords]).to include('パスワード')
      end
      
      it '推奨される解決アプローチを含める' do
        augmented = service.augment_query(query, context)
        
        expect(augmented[:suggested_approaches]).to be_an(Array)
        expect(augmented[:suggested_approaches]).not_to be_empty
      end
    end
  end
  
  describe '#generate_response' do
    context 'RAGベースの応答生成' do
      let(:query) { 'ログインできません' }
      let(:conversation) { create(:conversation) }
      let(:context) do
        {
          query: query,
          retrieved_messages: [
            { 
              message: create(:message, 
                            content: 'パスワードリセットで解決しました',
                            role: 'user'),
              score: 0.9 
            }
          ],
          relevant_solutions: ['パスワードリセット'],
          context_summary: 'ログイン問題の一般的な解決策'
        }
      end
      
      it 'コンテキストを活用した応答を生成する' do
        response = service.generate_response(query, context, conversation: conversation)
        
        expect(response[:content]).to be_present
        expect(response[:sources_used]).to be_an(Array)
        expect(response[:confidence_score]).to be_between(0, 1)
      end
      
      it '使用した情報源を明示する' do
        response = service.generate_response(query, context, conversation: conversation)
        
        sources = response[:sources_used]
        expect(sources).not_to be_empty
        expect(sources.first).to include(:message_id, :relevance_score)
      end
      
      it '応答にメタデータを含める' do
        response = service.generate_response(query, context, conversation: conversation)
        
        expect(response[:metadata]).to include(
          :rag_enabled,
          :context_count,
          :generation_method,
          :timestamp
        )
        expect(response[:metadata][:rag_enabled]).to be true
        expect(response[:metadata][:context_count]).to eq(1)
      end
    end
  end
  
  describe '#rag_pipeline' do
    context '完全なRAGパイプライン' do
      let(:query) { 'パスワードをリセットしたい' }
      let(:conversation) { create(:conversation) }
      
      before do
        # 類似メッセージの準備
        similar_messages = [
          create(:message, content: 'パスワード忘れ', metadata: { resolution: 'リセットリンク送信' }),
          create(:message, content: 'ログイン不可', metadata: { resolution: 'パスワード再設定' }),
          create(:message, content: 'アカウントロック', metadata: { resolution: 'サポート連絡' })
        ]
        
        allow(vector_service).to receive(:find_similar_messages_with_scores)
          .and_return(similar_messages.map.with_index do |msg, idx|
            { message: msg, score: 0.9 - (idx * 0.05), distance: 0.1 + (idx * 0.05) }
          end)
      end
      
      it '取得、拡張、生成のパイプラインを実行する' do
        result = service.rag_pipeline(query, conversation: conversation)
        
        expect(result[:context]).to be_present
        expect(result[:augmented_query]).to be_present
        expect(result[:response]).to be_present
        expect(result[:performance_metrics]).to be_present
      end
      
      it 'パフォーマンスメトリクスを記録する' do
        result = service.rag_pipeline(query, conversation: conversation)
        
        metrics = result[:performance_metrics]
        expect(metrics[:retrieval_time_ms]).to be_a(Numeric)
        expect(metrics[:augmentation_time_ms]).to be_a(Numeric)
        expect(metrics[:generation_time_ms]).to be_a(Numeric)
        expect(metrics[:total_time_ms]).to be_a(Numeric)
      end
      
      it '類似メッセージが見つからない場合でも動作する' do
        allow(vector_service).to receive(:find_similar_messages_with_scores)
          .and_return([])
        
        result = service.rag_pipeline(query, conversation: conversation)
        
        expect(result[:response]).to be_present
        expect(result[:context][:retrieved_messages]).to be_empty
        expect(result[:response][:confidence_score]).to be < 0.5
      end
    end
  end
  
  describe '#evaluate_relevance' do
    context '取得情報の関連性評価' do
      let(:query) { 'パスワードリセット方法' }
      let(:retrieved_message) do
        create(:message, content: 'パスワードを忘れた場合の対処法')
      end
      
      before do
        allow(vector_service).to receive(:generate_embedding).and_return(Array.new(1536) { rand(-1.0..1.0) })
        allow(semantic_service).to receive(:calculate_similarity).and_return(0.8)
      end
      
      it '関連性スコアを計算する' do
        score = service.evaluate_relevance(query, retrieved_message)
        
        expect(score).to be_between(0, 1)
        expect(score).to be > 0.5 # 関連性が高い
      end
      
      it '無関係なメッセージには低スコアを付ける' do
        unrelated = create(:message, content: '配送状況の確認')
        allow(semantic_service).to receive(:calculate_similarity).and_return(-0.5)
        
        score = service.evaluate_relevance(query, unrelated)
        
        expect(score).to be < 0.3
      end
    end
  end
  
  describe '#cache_retrieval' do
    context '取得結果のキャッシング' do
      let(:query) { 'よくある質問' }
      
      it '同じクエリの結果をキャッシュする' do
        # 初回取得
        allow(vector_service).to receive(:find_similar_messages_with_scores)
          .with(query, limit: 3)
          .and_return([])
          .once # 1回だけ呼ばれることを期待
        
        result1 = service.retrieve_context(query, use_cache: true)
        result2 = service.retrieve_context(query, use_cache: true)
        
        expect(result1).to eq(result2)
      end
      
      it 'TTL後はキャッシュを更新する' do
        allow(vector_service).to receive(:find_similar_messages_with_scores)
          .with(query, limit: 3)
          .and_return([])
        
        service.retrieve_context(query, use_cache: true, cache_ttl: 0.001)
        sleep 0.002
        
        # TTL経過後は再度取得される
        expect(vector_service).to receive(:find_similar_messages_with_scores)
          .with(query, limit: 3)
        service.retrieve_context(query, use_cache: true, cache_ttl: 0.001)
      end
    end
  end
  
  describe '#filter_by_date' do
    context '日付による取得結果のフィルタリング' do
      before do
        @old_message = create(:message, 
                             content: '古い解決策',
                             created_at: 1.year.ago)
        @recent_message = create(:message,
                                content: '最新の解決策',
                                created_at: 1.day.ago)
      end
      
      it '指定期間内のメッセージのみ取得する' do
        messages = [
          { message: @old_message, score: 0.9 },
          { message: @recent_message, score: 0.8 }
        ]
        
        filtered = service.filter_by_date(messages, days: 30)
        
        expect(filtered.size).to eq(1)
        expect(filtered.first[:message]).to eq(@recent_message)
      end
      
      it '期間指定なしの場合は全て返す' do
        messages = [
          { message: @old_message, score: 0.9 },
          { message: @recent_message, score: 0.8 }
        ]
        
        filtered = service.filter_by_date(messages)
        
        expect(filtered.size).to eq(2)
      end
    end
  end
  
  describe '#rank_solutions' do
    context '解決策のランク付け' do
      let(:solutions) do
        [
          { solution: 'パスワードリセット', success_count: 50, attempt_count: 55 },
          { solution: 'キャッシュクリア', success_count: 30, attempt_count: 40 },
          { solution: 'ブラウザ変更', success_count: 10, attempt_count: 50 }
        ]
      end
      
      it '成功率でランク付けする' do
        ranked = service.rank_solutions(solutions)
        
        expect(ranked.first[:solution]).to eq('パスワードリセット')
        expect(ranked.first[:success_rate]).to be_within(0.01).of(0.91)
        expect(ranked.last[:solution]).to eq('ブラウザ変更')
      end
      
      it 'ランクスコアを付与する' do
        ranked = service.rank_solutions(solutions)
        
        ranked.each do |solution|
          expect(solution[:rank_score]).to be_between(0, 100)
        end
        
        # スコアが降順であることを確認
        scores = ranked.map { |s| s[:rank_score] }
        expect(scores).to eq(scores.sort.reverse)
      end
    end
  end
  
  describe '#merge_contexts' do
    context '複数のコンテキストソースの統合' do
      let(:message_context) do
        {
          source: 'messages',
          items: [create(:message, content: 'メッセージ履歴から')]
        }
      end
      
      let(:kb_context) do
        {
          source: 'knowledge_base',
          items: [create(:knowledge_base, content: { info: 'ナレッジベースから' })]
        }
      end
      
      it '異なるソースからのコンテキストを統合する' do
        merged = service.merge_contexts([message_context, kb_context])
        
        expect(merged[:sources]).to include('messages', 'knowledge_base')
        expect(merged[:total_items]).to eq(2)
        expect(merged[:items]).to be_an(Array)
      end
      
      it '重複を除去して統合する' do
        duplicate_context = {
          source: 'messages',
          items: message_context[:items] # 同じアイテム
        }
        
        merged = service.merge_contexts([message_context, duplicate_context])
        
        expect(merged[:total_items]).to eq(1) # 重複除去
      end
    end
  end
  
  describe '#adaptive_retrieval' do
    context '適応的な取得戦略' do
      let(:query) { '緊急：システムダウン' }
      
      it '緊急度に応じて取得数を調整する' do
        context = service.adaptive_retrieval(query, urgency: 'high')
        
        # 緊急時はより多くの情報を取得
        expect(context[:retrieval_limit]).to be > 3
        expect(context[:threshold]).to be < 0.7 # 閾値を下げて幅広く取得
      end
      
      it 'クエリの複雑さに基づいて戦略を変更する' do
        complex_query = 'ログインエラーが発生し、パスワードリセットも失敗、二段階認証も通らない'
        
        context = service.adaptive_retrieval(complex_query)
        
        expect(context[:strategy]).to eq('multi_stage')
        expect(context[:stages]).to be > 1
      end
    end
  end
end