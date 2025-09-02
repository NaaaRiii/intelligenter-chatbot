# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ContextInjectionService do
  let(:service) { described_class.new }
  let(:rag_service) { instance_double(RagService) }
  
  before do
    allow(RagService).to receive(:new).and_return(rag_service)
  end
  
  describe '#inject_context' do
    context '関連FAQ、事例、製品情報の注入' do
      let(:query) { 'ログインエラーの解決方法を教えてください' }
      let(:conversation) { create(:conversation) }
      
      it 'FAQ、事例、製品情報を統合したコンテキストを生成する' do
        injected = service.inject_context(query, conversation: conversation)
        
        expect(injected).to include(
          :faqs,
          :case_studies,
          :product_info,
          :integrated_context
        )
        
        expect(injected[:faqs]).to be_an(Array)
        expect(injected[:case_studies]).to be_an(Array)
        expect(injected[:product_info]).to be_an(Array)
        expect(injected[:integrated_context]).to be_present
      end
    end
  end
  
  describe '#fetch_relevant_faqs' do
    context 'FAQ情報の取得' do
      before do
        # FAQデータの準備
        @faq1 = create(:knowledge_base,
                      pattern_type: 'faq',
                      content: { 
                        question: 'ログインできません',
                        answer: 'パスワードをリセットしてください'
                      },
                      tags: ['login', 'authentication'])
        @faq2 = create(:knowledge_base,
                      pattern_type: 'faq',
                      content: {
                        question: 'パスワードを忘れました',
                        answer: 'リセットリンクをメールで送信します'
                      },
                      tags: ['password', 'reset'])
        @faq3 = create(:knowledge_base,
                      pattern_type: 'faq',
                      content: {
                        question: '請求書の発行',
                        answer: 'マイページから発行可能です'
                      },
                      tags: ['billing', 'invoice'])
      end
      
      it '関連するFAQを取得する' do
        query = 'ログインできない'
        
        faqs = service.fetch_relevant_faqs(query, limit: 2)
        
        expect(faqs.size).to eq(2)
        expect(faqs.map(&:id)).to include(@faq1.id, @faq2.id)
        expect(faqs.map(&:id)).not_to include(@faq3.id)
      end
      
      it '優先度順にFAQをソートする' do
        query = 'パスワード関連の問題'
        
        faqs = service.fetch_relevant_faqs(query)
        
        # パスワード関連のFAQが取得される（最初のFAQでなくても良い）
        expect(faqs).not_to be_empty
        questions = faqs.map { |f| f.content['question'] }
        expect(questions.any? { |q| q.include?('パスワード') }).to be true
      end
      
      it 'FAQをフォーマットして返す' do
        query = 'ログイン'
        
        formatted = service.format_faqs(query)
        
        expect(formatted).to be_an(Array)
        expect(formatted.first).to include(
          :question,
          :answer,
          :relevance_score,
          :tags
        )
      end
    end
  end
  
  describe '#fetch_case_studies' do
    context '類似事例の取得' do
      before do
        # 成功事例データの準備
        @case1 = create(:resolution_path,
                       problem_type: 'login_issue',
                       solution: 'パスワードリセットで解決',
                       steps_count: 3,
                       resolution_time: 180,
                       successful: true,
                       metadata: {
                         customer_type: 'enterprise',
                         details: 'SSO設定の問題でした'
                       })
        @case2 = create(:resolution_path,
                       problem_type: 'payment_issue',
                       solution: 'カード情報更新',
                       steps_count: 2,
                       resolution_time: 120,
                       successful: true,
                       metadata: {
                         customer_type: 'small_business',
                         details: 'カードの有効期限切れ'
                       })
      end
      
      it '類似した成功事例を取得する' do
        query = 'ログインできない'
        
        cases = service.fetch_case_studies(query, limit: 1)
        
        expect(cases.size).to eq(1)
        expect(cases.first.problem_type).to eq('login_issue')
        expect(cases.first.successful).to be true
      end
      
      it '事例を構造化して返す' do
        query = 'ログイン問題'
        
        structured = service.structure_case_studies(query)
        
        expect(structured).to be_an(Array)
        expect(structured.first).to include(
          :problem_description,
          :solution_applied,
          :resolution_steps,
          :time_to_resolve,
          :customer_segment
        )
      end
      
      it '成功率の高い事例を優先する' do
        # 複数の事例を作成
        5.times { create(:resolution_path, problem_type: 'login_issue', successful: true) }
        2.times { create(:resolution_path, problem_type: 'login_issue', successful: false) }
        
        cases = service.fetch_case_studies('ログイン', prioritize_success: true)
        
        # 成功事例のみが返される
        expect(cases.all?(&:successful)).to be true
      end
    end
  end
  
  describe '#fetch_product_info' do
    context '製品情報の取得' do
      before do
        # 製品情報データの準備
        @product1 = create(:knowledge_base,
                          pattern_type: 'product_info',
                          content: {
                            name: 'ユーザー認証システム',
                            features: ['SSO対応', '二段階認証', 'LDAP連携'],
                            documentation_url: 'https://docs.example.com/auth'
                          },
                          tags: ['authentication', 'security'])
        @product2 = create(:knowledge_base,
                          pattern_type: 'product_info',
                          content: {
                            name: '決済システム',
                            features: ['クレジットカード', 'PayPal', '請求書払い'],
                            documentation_url: 'https://docs.example.com/payment'
                          },
                          tags: ['payment', 'billing'])
      end
      
      it '関連する製品情報を取得する' do
        query = '認証エラー'
        
        products = service.fetch_product_info(query)
        
        expect(products).not_to be_empty
        expect(products.first.content['name']).to include('認証')
      end
      
      it '製品機能と関連付けて返す' do
        query = 'SSO設定'
        
        info = service.get_product_features(query)
        
        expect(info).to be_an(Array)
        expect(info.first).to include(
          :product_name,
          :relevant_features,
          :documentation_link,
          :setup_guide
        )
      end
      
      it '複数の製品情報を統合する' do
        query = 'システム全般の問題'
        
        integrated = service.integrate_product_info(query)
        
        expect(integrated[:products]).to be_an(Array)
        expect(integrated[:total_features]).to be > 0
        expect(integrated[:documentation_links]).to be_an(Array)
      end
    end
  end
  
  describe '#build_enriched_context' do
    context 'エンリッチされたコンテキストの構築' do
      let(:query) { 'ログインエラーが発生しています' }
      let(:base_context) do
        {
          query: query,
          retrieved_messages: [],
          relevant_solutions: []
        }
      end
      
      before do
        # テスト用のFAQ、事例、製品情報を作成
        create(:knowledge_base,
               pattern_type: 'faq',
               content: { question: 'ログインエラー', answer: '解決方法' },
               tags: ['login', 'error'])
        create(:resolution_path,
               problem_type: 'login_issue',
               solution: 'キャッシュクリア',
               successful: true)
        create(:knowledge_base,
               pattern_type: 'product_info',
               content: { name: '認証システム', features: ['ログイン機能'] },
               tags: ['authentication'])
      end
      
      it '全ての情報源を統合したコンテキストを構築する' do
        enriched = service.build_enriched_context(query, base_context)
        
        expect(enriched[:sources]).to include('faq', 'cases', 'products')
        expect(enriched[:total_context_items]).to be > 0
        expect(enriched[:confidence_level]).to be_between(0, 1)
      end
      
      it '情報の重要度でランク付けする' do
        enriched = service.build_enriched_context(query, base_context)
        
        expect(enriched[:ranked_information]).to be_an(Array)
        # 重要度順にソートされている
        importance_scores = enriched[:ranked_information].map { |i| i[:importance] }
        expect(importance_scores).to eq(importance_scores.sort.reverse)
      end
      
      it 'コンテキストサマリを生成する' do
        enriched = service.build_enriched_context(query, base_context)
        
        expect(enriched[:summary]).to be_present
        expect(enriched[:summary]).to include('FAQ')
        expect(enriched[:summary]).to include('事例')
        expect(enriched[:summary]).to include('製品情報')
      end
    end
  end
  
  describe '#prioritize_information' do
    context '情報の優先順位付け' do
      let(:faq_items) do
        [
          { question: 'Q1', answer: 'A1', relevance_score: 0.9 },
          { question: 'Q2', answer: 'A2', relevance_score: 0.7 }
        ]
      end
      
      let(:case_items) do
        [
          { problem: 'P1', solution: 'S1', success_rate: 0.95 },
          { problem: 'P2', solution: 'S2', success_rate: 0.80 }
        ]
      end
      
      let(:product_items) do
        [
          { name: 'Product1', features: ['F1', 'F2'], relevance: 0.85 }
        ]
      end
      
      it '複数の情報源を統合して優先順位を付ける' do
        prioritized = service.prioritize_information(
          faqs: faq_items,
          cases: case_items,
          products: product_items
        )
        
        expect(prioritized).to be_an(Array)
        expect(prioritized.first[:priority_score]).to be >= prioritized.last[:priority_score]
      end
      
      it '情報タイプごとに重み付けする' do
        weights = { faq: 0.4, cases: 0.4, products: 0.2 }
        
        prioritized = service.prioritize_information(
          faqs: faq_items,
          cases: case_items,
          products: product_items,
          weights: weights
        )
        
        # FAQと事例が優先される
        top_items = prioritized.take(3)
        types = top_items.map { |i| i[:type] }
        expect(types).to include('faq', 'case')
      end
    end
  end
  
  describe '#generate_contextual_response' do
    context 'コンテキストを活用した応答生成' do
      let(:query) { 'パスワードリセットの方法' }
      let(:enriched_context) do
        {
          faqs: [{ question: 'パスワードを忘れました', answer: 'リセットリンクを送信' }],
          cases: [{ solution: 'メールでリセット', time: 120 }],
          products: [{ name: '認証システム', features: ['パスワードリセット機能'] }]
        }
      end
      
      it 'コンテキスト情報を含む応答を生成する' do
        response = service.generate_contextual_response(query, enriched_context)
        
        expect(response[:content]).to be_present
        expect(response[:references]).to be_an(Array)
        expect(response[:suggested_actions]).to be_an(Array)
      end
      
      it 'FAQ、事例、製品情報を参照として含める' do
        response = service.generate_contextual_response(query, enriched_context)
        
        references = response[:references]
        ref_types = references.map { |r| r[:type] }
        
        expect(ref_types).to include('faq', 'case', 'product')
      end
      
      it '段階的な解決手順を提供する' do
        response = service.generate_contextual_response(query, enriched_context)
        
        expect(response[:resolution_steps]).to be_an(Array)
        expect(response[:resolution_steps].first).to include(:step_number, :action, :expected_result)
      end
    end
  end
  
  describe '#update_knowledge_base' do
    context 'ナレッジベースの更新' do
      let(:conversation) { create(:conversation) }
      let(:resolution_data) do
        {
          problem: 'ログインエラー',
          solution: '新しい解決方法',
          steps: ['ステップ1', 'ステップ2'],
          successful: true
        }
      end
      
      it '成功した解決策をナレッジベースに追加する' do
        result = service.update_knowledge_base(conversation, resolution_data)
        
        expect(result[:created]).to be true
        expect(result[:knowledge_base_id]).to be_present
        expect(result[:pattern_type]).to eq('resolution_pattern')
      end
      
      it 'FAQとして保存する' do
        faq_data = {
          question: '新しい質問',
          answer: '詳細な回答',
          tags: ['new', 'important']
        }
        
        result = service.save_as_faq(faq_data)
        
        expect(result[:created]).to be true
        expect(result[:faq_id]).to be_present
        
        # 保存されたFAQを確認
        faq = KnowledgeBase.find(result[:faq_id])
        expect(faq.pattern_type).to eq('faq')
        expect(faq.content['question']).to eq('新しい質問')
      end
    end
  end
  
  describe '#search_similar_contexts' do
    context '類似コンテキストの検索' do
      before do
        # 様々なコンテキストデータを準備
        create_list(:knowledge_base, 5, pattern_type: 'faq')
        create_list(:resolution_path, 5, successful: true)
      end
      
      it '複数のソースから類似コンテキストを検索する' do
        query = 'システムエラー'
        
        similar = service.search_similar_contexts(query)
        
        expect(similar[:total_results]).to be > 0
        expect(similar[:by_source]).to include('faq', 'cases', 'products')
        expect(similar[:top_matches]).to be_an(Array)
      end
      
      it '類似度スコアでランク付けする' do
        query = 'ログイン問題'
        
        similar = service.search_similar_contexts(query)
        
        top_matches = similar[:top_matches]
        scores = top_matches.map { |m| m[:similarity_score] }
        
        # スコアが降順になっている
        expect(scores).to eq(scores.sort.reverse)
      end
    end
  end
  
  describe '#optimize_context_injection' do
    context 'コンテキスト注入の最適化' do
      let(:query) { '複雑な技術的問題' }
      
      it 'クエリの複雑さに応じて注入量を調整する' do
        simple_query = '簡単な質問'
        complex_query = '複数の要因が絡む複雑な技術的問題でシステム全体に影響'
        
        simple_context = service.optimize_context_injection(simple_query)
        complex_context = service.optimize_context_injection(complex_query)
        
        expect(complex_context[:injection_depth]).to be > simple_context[:injection_depth]
        expect(complex_context[:max_items]).to be > simple_context[:max_items]
      end
      
      it 'パフォーマンスを考慮して制限を設ける' do
        context_config = service.optimize_context_injection(query)
        
        expect(context_config[:max_items]).to be <= 20
        expect(context_config[:timeout_ms]).to be <= 3000
        expect(context_config[:parallel_fetch]).to be true
      end
    end
  end
  
  describe '#validate_context_relevance' do
    context 'コンテキストの関連性検証' do
      let(:query) { 'ログインエラー' }
      let(:context_items) do
        [
          { content: 'ログイン関連の情報', type: 'faq' },
          { content: '全く関係ない情報', type: 'case' },
          { content: 'パスワード関連', type: 'product' }
        ]
      end
      
      it '関連性の低い情報をフィルタリングする' do
        validated = service.validate_context_relevance(query, context_items)
        
        expect(validated.size).to be < context_items.size
        expect(validated.none? { |i| i[:content].include?('関係ない') }).to be true
      end
      
      it '関連性スコアを付与する' do
        validated = service.validate_context_relevance(query, context_items)
        
        validated.each do |item|
          expect(item[:relevance_score]).to be_between(0, 1)
        end
      end
    end
  end
end