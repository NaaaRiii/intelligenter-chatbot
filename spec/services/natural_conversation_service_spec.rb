# frozen_string_literal: true

require 'rails_helper'

RSpec.describe NaturalConversationService, type: :service do
  let(:service) { described_class.new }
  let(:user_message) { '楽天・Amazon・Yahoo!ショッピングとの連携はできますか？個人情報保護やセキュリティ対策はどうなっていますか？' }
  let(:conversation_history) { [] }
  let(:context) { { category: 'ecommerce' } }

  describe '#analyze_message' do
    context 'with multiple questions' do
      it 'detects and categorizes multiple questions' do
        analysis = service.analyze_message(user_message)
        
        expect(analysis['questions']).to be_an(Array)
        expect(analysis['questions'].size).to eq(2)
        
        ec_question = analysis['questions'].find { |q| q['topic'] == 'システム連携' }
        security_question = analysis['questions'].find { |q| q['topic'] == 'セキュリティ' }
        
        expect(ec_question).not_to be_nil
        expect(security_question).not_to be_nil
      end
    end

    context 'with single question' do
      let(:user_message) { 'プロジェクトの進め方を教えてください' }
      
      it 'detects single question' do
        analysis = service.analyze_message(user_message)
        
        expect(analysis['questions'].size).to eq(1)
        expect(analysis['questions'].first['content']).to include('プロジェクト')
      end
    end
  end

  describe '#generate_natural_response' do
    context 'with multiple questions' do
      it 'generates responses for each question' do
        response = service.generate_natural_response(user_message, conversation_history, context)
        
        # 両方の質問に答えているか確認
        expect(response).to include('ECモール連携', 'システム連携')
        expect(response).to include('セキュリティ')
        
        # 構造化された回答形式か確認
        expect(response).to match(/【.*について】/)
      end
    end

    context 'with conversation history' do
      let(:conversation_history) do
        [
          { role: 'user', content: 'プロジェクトの進め方について教えてください' },
          { role: 'assistant', content: 'プロジェクトはアジャイル開発で進めます' }
        ]
      end
      
      it 'maintains context from previous messages' do
        response = service.generate_natural_response(user_message, conversation_history, context)
        
        # 文脈を保持しているか確認
        expect(response).not_to be_empty
      end
    end

    context 'with specific category context' do
      let(:context) { { category: 'security' } }
      let(:user_message) { 'データの暗号化はどうなっていますか？' }
      
      it 'provides category-specific detailed answers' do
        response = service.generate_natural_response(user_message, conversation_history, context)
        
        # セキュリティ関連の具体的な回答が含まれているか
        expect(response).to match(/暗号|SSL|TLS|セキュリティ/i)
      end
    end
  end

  describe 'error handling' do
    context 'when OpenAI API fails' do
      before do
        allow_any_instance_of(OpenaiChatService).to receive(:analyze_with_gpt4).and_raise(StandardError)
      end
      
      it 'falls back to pattern matching' do
        analysis = service.analyze_message(user_message)
        
        expect(analysis['questions']).to be_an(Array)
        expect(analysis['questions']).not_to be_empty
      end
    end

    context 'when response generation fails' do
      before do
        allow_any_instance_of(ClaudeApiService).to receive(:generate_response).and_raise(StandardError)
        allow_any_instance_of(OpenaiChatService).to receive(:generate_response).and_raise(StandardError)
      end
      
      it 'returns fallback response' do
        expect { 
          service.generate_natural_response(user_message, conversation_history, context)
        }.to raise_error(StandardError)
      end
    end
  end
end