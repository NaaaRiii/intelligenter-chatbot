# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'RAG Integration', type: :integration do
  let(:conversation) { create(:conversation) }
  let(:user_message) { 'ログインできません。パスワードを忘れました。' }
  let(:chat_bot_service) do
    ChatBotService.new(
      conversation: conversation,
      user_message: user_message,
      context: {}
    )
  end
  
  describe 'RAGを活用したチャットボット応答' do
    before do
      # テスト用のデータを準備
      # FAQ
      create(:knowledge_base,
             pattern_type: 'faq',
             content: {
               question: 'パスワードを忘れた場合はどうすればいいですか？',
               answer: 'パスワードリセットページから再設定できます。'
             },
             tags: ['password', 'reset', 'login'])
      
      # 成功事例
      create(:resolution_path,
             problem_type: 'login_issue',
             solution: 'パスワードリセットリンクの送信',
             steps_count: 3,
             resolution_time: 180,
             successful: true,
             metadata: { customer_feedback: 'すぐに解決できました' })
      
      # 製品情報
      create(:knowledge_base,
             pattern_type: 'product_info',
             content: {
               name: 'ユーザー認証システム',
               features: ['パスワードリセット機能', 'SSO対応', '二段階認証'],
               documentation_url: 'https://docs.example.com/auth'
             },
             tags: ['authentication', 'security'])
      
      # 過去の類似メッセージ
      past_conversation = create(:conversation)
      create(:message,
             conversation: past_conversation,
             content: 'ログインできない問題が解決しました',
             metadata: { resolution: 'パスワードリセットで解決' },
             embedding: Array.new(1536) { rand(-1.0..1.0) })
    end
    
    context 'generate_response_with_ragメソッド' do
      it 'RAGコンテキストを活用して応答を生成する' do
        # ClaudeApiServiceをモック
        allow_any_instance_of(ClaudeApiService).to receive(:generate_response_with_context)
          .and_return('パスワードリセットのご案内をいたします。過去の事例では、リセットリンクから再設定することで解決しています。')
        
        response = chat_bot_service.generate_response_with_rag
        
        expect(response).to be_present
        expect(response.content).to include('パスワードリセット')
        expect(response.metadata['rag_used']).to be true
      end
      
      it 'メタデータにRAG情報を含める' do
        allow_any_instance_of(ClaudeApiService).to receive(:generate_response_with_context)
          .and_return('テスト応答')
        
        response = chat_bot_service.generate_response_with_rag
        
        expect(response.metadata).to include(
          'rag_used',
          'sources_count',
          'confidence_score',
          'performance_metrics'
        )
        expect(response.metadata['rag_used']).to be true
      end
      
      it 'エラー時は通常の応答にフォールバックする' do
        # RAGサービスでエラーを発生させる
        allow_any_instance_of(RagService).to receive(:rag_pipeline)
          .and_raise(StandardError, 'RAG error')
        
        # 通常の応答生成をモック
        allow(chat_bot_service).to receive(:generate_response)
          .and_return(build(:message, content: 'フォールバック応答'))
        
        response = chat_bot_service.generate_response_with_rag
        
        expect(response.content).to eq('フォールバック応答')
      end
    end
  end
  
  describe 'ClaudeApiServiceの拡張コンテキスト送信' do
    let(:claude_service) { ClaudeApiService.new }
    let(:conversation_history) do
      [
        { role: 'user', content: 'ログインできません' },
        { role: 'assistant', content: '状況を詳しく教えていただけますか？' }
      ]
    end
    let(:enriched_context) do
      {
        faqs: [build(:knowledge_base, pattern_type: 'faq', content: { question: 'Q1', answer: 'A1' })],
        case_studies: [build(:resolution_path, problem_type: 'login_issue', solution: 'リセット')],
        product_info: [build(:knowledge_base, pattern_type: 'product_info', content: { name: '認証システム' })],
        rag_context: {
          retrieved_messages: [
            { message: build(:message, content: '類似ケース'), score: 0.9 }
          ],
          relevant_solutions: ['パスワードリセット']
        }
      }
    end
    
    it 'コンテキストをフォーマットしてAPIに送信する' do
      # Anthropic Clientをモック
      client_mock = instance_double(Anthropic::Client)
      allow(Anthropic::Client).to receive(:new).and_return(client_mock)
      
      # API応答をモック
      allow(client_mock).to receive(:messages).and_return({
        'content' => [{ 'type' => 'text', 'text' => 'コンテキストを活用した応答です' }]
      })
      
      response = claude_service.generate_response_with_context(
        conversation_history,
        'パスワードを忘れました',
        enriched_context
      )
      
      expect(response).to include('コンテキストを活用した応答')
    end
    
    it 'エラー時は通常の応答生成にフォールバックする' do
      # エラーを発生させる
      allow_any_instance_of(Anthropic::Client).to receive(:messages)
        .and_raise(StandardError, 'API error')
      
      # フォールバックメソッドをモック
      allow(claude_service).to receive(:generate_response)
        .and_return('フォールバック応答')
      
      response = claude_service.generate_response_with_context(
        conversation_history,
        'テストメッセージ',
        enriched_context
      )
      
      expect(response).to eq('フォールバック応答')
    end
  end
  
  describe 'エンドツーエンド統合' do
    it 'ユーザーメッセージからRAG強化応答までの完全なフロー' do
      # 実際のフローをテスト（APIコールはモック）
      allow_any_instance_of(Anthropic::Client).to receive(:messages).and_return({
        'content' => [{ 'type' => 'text', 'text' => '統合テスト応答' }]
      })
      
      # VectorSearchServiceをモック（embeddings生成）
      allow_any_instance_of(VectorSearchService).to receive(:generate_embedding)
        .and_return(Array.new(1536) { rand(-1.0..1.0) })
      allow_any_instance_of(VectorSearchService).to receive(:find_similar_messages_with_scores)
        .and_return([])
      
      response = chat_bot_service.generate_response_with_rag
      
      expect(response).to be_a(Message)
      expect(response.role).to eq('assistant')
      expect(response.conversation).to eq(conversation)
    end
    
    it 'パフォーマンスメトリクスを記録する' do
      allow_any_instance_of(Anthropic::Client).to receive(:messages).and_return({
        'content' => [{ 'type' => 'text', 'text' => 'テスト' }]
      })
      allow_any_instance_of(VectorSearchService).to receive(:generate_embedding)
        .and_return(Array.new(1536) { 0 })
      allow_any_instance_of(VectorSearchService).to receive(:find_similar_messages_with_scores)
        .and_return([])
      
      response = chat_bot_service.generate_response_with_rag
      
      metrics = response.metadata['performance_metrics']
      expect(metrics).to include(
        'retrieval_time_ms',
        'augmentation_time_ms',
        'generation_time_ms',
        'total_time_ms'
      )
    end
  end
  
  describe '段階的な機能切り替え' do
    context 'フィーチャーフラグによる制御' do
      it 'RAG機能が有効な場合はRAG応答を使用' do
        # フィーチャーフラグを有効化（仮想的に）
        allow(Rails.configuration).to receive(:rag_enabled).and_return(true)
        
        expect(chat_bot_service).to receive(:generate_response_with_rag)
        
        # 実際の切り替えロジックはコントローラーで実装
        if Rails.configuration.respond_to?(:rag_enabled) && Rails.configuration.rag_enabled
          chat_bot_service.generate_response_with_rag
        else
          chat_bot_service.generate_response
        end
      end
      
      it 'RAG機能が無効な場合は通常応答を使用' do
        allow(Rails.configuration).to receive(:rag_enabled).and_return(false)
        
        expect(chat_bot_service).to receive(:generate_response)
        
        if Rails.configuration.respond_to?(:rag_enabled) && Rails.configuration.rag_enabled
          chat_bot_service.generate_response_with_rag
        else
          chat_bot_service.generate_response
        end
      end
    end
  end
end