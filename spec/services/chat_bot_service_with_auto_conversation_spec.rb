# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'ChatBotService with AutoConversation' do
  let(:chat_bot_service) { EnhancedChatBotService.new }
  let(:auto_service) { AutoConversationService.new }
  let(:conversation) { create(:conversation) }
  let(:user) { create(:user) }
  
  describe '#generate_auto_response' do
    context '初回メッセージの処理' do
      it '自動応答で必要情報を収集開始する' do
        user_message = 'ECサイトの売上を改善したいです'
        
        # ChatBotServiceが自動応答を生成
        response = chat_bot_service.generate_auto_response(
          conversation,
          user_message,
          auto_conversation: true
        )
        
        expect(response).not_to be_nil
        expect(response).to match(/予算|費用/)
        
        # メタデータが更新される
        conversation.reload
        metadata = conversation.metadata || {}
        expect(metadata['category']).to eq('marketing')
        expect(metadata['collected_info']).to have_key('business_type')
        expect(metadata['ai_interaction_count']).to eq(1)
      end
      
      it 'カテゴリを自動判定してメタデータに保存する' do
        messages = [
          { content: '広告の効果を改善したい', expected_category: 'marketing' },
          { content: 'APIエラーが発生している', expected_category: 'tech' },
          { content: '料金プランについて教えてください', expected_category: 'general' }
        ]
        
        messages.each do |msg|
          conv = create(:conversation)
          response = chat_bot_service.generate_auto_response(
            conv,
            msg[:content],
            auto_conversation: true
          )
          
          conv.reload
          expect(conv.metadata['category']).to eq(msg[:expected_category])
        end
      end
    end
    
    context '会話の継続判定' do
      it '3往復未満なら自動応答を継続する' do
        conversation.metadata = {
          'ai_interaction_count' => 2,
          'category' => 'marketing',
          'collected_info' => { 'business_type' => '小売業' }
        }
        conversation.save!
        
        should_continue = chat_bot_service.should_continue_auto_conversation?(conversation)
        expect(should_continue).to be true
      end
      
      it '必要情報が揃ったら人間にエスカレーション' do
        conversation.metadata = {
          'ai_interaction_count' => 2,
          'category' => 'marketing',
          'collected_info' => {
            'business_type' => '小売業',
            'budget_range' => '月額100万円',
            'current_tools' => 'Shopify'
          }
        }
        conversation.save!
        
        should_continue = chat_bot_service.should_continue_auto_conversation?(conversation)
        expect(should_continue).to be false
      end
      
      it '5往復に達したら自動的にエスカレーション' do
        conversation.metadata = {
          'ai_interaction_count' => 5,
          'category' => 'marketing',
          'collected_info' => { 'business_type' => '小売業' }
        }
        conversation.save!
        
        should_continue = chat_bot_service.should_continue_auto_conversation?(conversation)
        expect(should_continue).to be false
      end
    end
    
    context '情報抽出と保存' do
      before do
        conversation.metadata = {
          'ai_interaction_count' => 1,
          'category' => 'marketing',
          'collected_info' => { 'business_type' => 'EC' }
        }
        conversation.save!
      end
      
      it 'ユーザーの回答から情報を抽出してメタデータに追加する' do
        user_message = '月額予算は100万円です'
        
        response = chat_bot_service.generate_auto_response(
          conversation,
          user_message,
          auto_conversation: true
        )
        
        conversation.reload
        collected_info = conversation.metadata['collected_info']
        expect(collected_info['budget_range']).to match(/100万/)
        expect(conversation.metadata['ai_interaction_count']).to eq(2)
      end
      
      it '複数の情報を一度に抽出できる' do
        user_message = 'アパレル業界で、Shopifyを使っています。月額50万円の予算です'
        
        response = chat_bot_service.generate_auto_response(
          conversation,
          user_message,
          auto_conversation: true
        )
        
        conversation.reload
        collected_info = conversation.metadata['collected_info']
        expect(collected_info['business_type']).to match(/アパレル/)
        expect(collected_info['current_tools']).to include('Shopify')
        expect(collected_info['budget_range']).to match(/50万/)
      end
    end
    
    context '完了時の処理' do
      it '必要情報が揃ったらサマリーを生成する' do
        conversation.metadata = {
          'ai_interaction_count' => 2,
          'category' => 'marketing',
          'collected_info' => {
            'business_type' => '小売業',
            'budget_range' => '月額100万円'
          }
        }
        conversation.save!
        
        user_message = 'Shopifyを使っています'
        response = chat_bot_service.generate_auto_response(
          conversation,
          user_message,
          auto_conversation: true
        )
        
        expect(response).to include('ご相談内容を確認')
        expect(response).to include('小売業')
        expect(response).to include('100万円')
        expect(response).to include('Shopify')
        expect(response).to include('専門のスタッフ')
        
        # エスカレーションフラグを立てる
        conversation.reload
        expect(conversation.metadata['escalation_required']).to be true
      end
      
      it '会話上限に達したら適切なメッセージを返す' do
        conversation.metadata = {
          'ai_interaction_count' => 4,
          'category' => 'marketing',
          'collected_info' => { 'business_type' => '小売業' }
        }
        conversation.save!
        
        user_message = '予算はまだ決まっていません'
        response = chat_bot_service.generate_auto_response(
          conversation,
          user_message,
          auto_conversation: true
        )
        
        expect(response).to include('専門のスタッフ')
        
        conversation.reload
        expect(conversation.metadata['ai_interaction_count']).to eq(5)
        expect(conversation.metadata['escalation_required']).to be true
      end
    end
    
    context 'エラーハンドリング' do
      it 'AutoConversationServiceがエラーになってもフォールバック応答を返す' do
        allow_any_instance_of(AutoConversationService).to receive(:process_initial_message)
          .and_raise(StandardError, 'Test error')
        
        response = chat_bot_service.generate_auto_response(
          conversation,
          'テストメッセージ',
          auto_conversation: true
        )
        
        expect(response).to include('申し訳ございません')
        expect(response).to include('サポートチーム')
      end
    end
  end
  
  describe '#should_continue_auto_conversation?' do
    it 'auto_conversationフラグがfalseなら継続しない' do
      conversation.metadata = { 'auto_conversation' => false }
      conversation.save!
      
      expect(chat_bot_service.should_continue_auto_conversation?(conversation)).to be false
    end
    
    it 'エスカレーションフラグが立っていたら継続しない' do
      conversation.metadata = { 'escalation_required' => true }
      conversation.save!
      
      expect(chat_bot_service.should_continue_auto_conversation?(conversation)).to be false
    end
  end
end