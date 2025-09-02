# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'コンテキスト管理統合テスト', type: :integration do
  let(:context_service) { ConversationContextService.new }
  let(:auto_conversation_service) { AutoConversationService.new }
  let(:user) { create(:user) }
  let(:conversation) { create(:conversation, user: user) }
  
  describe '会話フロー全体でのコンテキスト管理' do
    context '複数回の会話でコンテキストを維持' do
      it '過去の会話内容を参照して適切な応答を生成する' do
        # 1回目の会話
        message1 = create(:message, conversation: conversation, role: 'user',
                         content: 'ECサイトのマーケティングツールを探しています')
        
        context1 = context_service.build_context(conversation)
        
        expect(context1[:key_points]['category']).to eq('marketing')
        expect(context1[:current_topic]).to include('ツール選定')
        
        # 2回目の会話（予算について）
        message2 = create(:message, conversation: conversation, role: 'assistant',
                         content: 'ご予算はどの程度をお考えですか？')
        message3 = create(:message, conversation: conversation, role: 'user',
                         content: '月額100万円程度で考えています')
        
        context2 = context_service.build_context(conversation)
        
        expect(context2[:key_points]['category']).to eq('marketing')
        expect(context2[:current_topic]).to eq('予算確認')
        
        # エンティティ抽出確認
        entities = context_service.extract_entities([
          { content: message3.content }
        ])
        expect(entities[:budget]).to eq('月額100万円')
      end
    end
    
    context '顧客の過去の会話を参照' do
      let!(:past_conversation) do
        conv = create(:conversation, user: user, created_at: 1.month.ago)
        conv.metadata = {
          'category' => 'marketing',
          'resolved' => true,
          'solution' => 'HubSpot導入',
          'collected_info' => {
            'business_type' => 'BtoB SaaS',
            'budget_range' => '月額50万円'
          }
        }
        conv.save!
        conv
      end
      
      it '同じ顧客の過去の解決策を参照できる' do
        relevant = context_service.get_relevant_context(conversation)
        
        expect(relevant[:past_conversations]).to be_present
        expect(relevant[:previous_solutions]).to include('HubSpot導入')
        expect(relevant[:customer_history][:total_conversations]).to eq(1)
      end
      
      it '過去の会話と現在の会話の関連性を計算できる' do
        # 現在の会話のコンテキスト
        current_context = {
          key_points: {
            'category' => 'marketing',
            'business_type' => 'BtoB SaaS',
            'budget' => '月額80万円'
          }
        }
        
        # 過去の会話のコンテキスト
        past_context = {
          key_points: past_conversation.metadata
        }
        
        relevance = context_service.calculate_context_relevance(
          current_context,
          past_context
        )
        
        expect(relevance).to be > 0.5 # カテゴリと事業タイプが一致
      end
    end
    
    context '長い会話の要約とコンテキスト維持' do
      before do
        # 10往復の会話を作成
        10.times do |i|
          create(:message, conversation: conversation, role: 'user',
                 content: "質問#{i + 1}：機能について詳しく教えてください")
          create(:message, conversation: conversation, role: 'assistant',
                 content: "回答#{i + 1}：こちらが機能の詳細です。弊社のツールではCVR改善に特化した機能を提供しています。")
        end
      end
      
      it '長い会話を要約して重要ポイントを維持する' do
        context = context_service.build_context(conversation)
        
        # 要約が生成される
        expect(context[:summary]).to be_present
        expect(context[:summary]).to include('CVR改善')
        
        # 直近のメッセージが保持される
        expect(context[:recent_messages].count).to eq(10)
        expect(context[:recent_messages].last[:content]).to include('回答10')
        
        # 全体の会話履歴も保持
        expect(context[:conversation_history].count).to eq(20)
      end
    end
    
    context '意図判定とコンテキスト更新' do
      it '会話の流れから適切な意図を判定する' do
        messages = [
          { role: 'user', content: 'デモを見せてもらえますか？' }
        ]
        
        intent = context_service.determine_intent(messages)
        expect(intent[:type]).to eq('demo_request')
        
        # 複数の意図がある場合
        messages2 = [
          { role: 'user', content: '他社との違いを教えてください。あと料金プランも知りたいです。' }
        ]
        
        intent2 = context_service.determine_intent(messages2)
        expect(intent2[:primary]).to eq('comparison')
        expect(intent2[:secondary]).to include('pricing_inquiry')
      end
      
      it 'トピックの変化を検出してコンテキストを更新する' do
        initial_context = {
          current_topic: '機能説明',
          conversation_history: []
        }
        
        # 技術サポートへのトピック変更
        new_message = {
          role: 'user',
          content: 'エラーが発生して動かなくなりました'
        }
        
        updated = context_service.update_context(initial_context, new_message)
        
        expect(updated[:current_topic]).to eq('技術サポート')
        expect(updated[:topic_changed]).to be true
      end
    end
    
    context '自動会話とコンテキスト管理の統合' do
      it '収集した情報をコンテキストとして保持する' do
        # 初回メッセージ
        create(:message, conversation: conversation, role: 'user',
               content: 'Webマーケティングツールの導入を検討しています')
        
        response1 = auto_conversation_service.process_message(
          conversation,
          'Webマーケティングツールの導入を検討しています'
        )
        
        # コンテキストを構築
        context = context_service.build_context(conversation)
        
        expect(context[:key_points]['category']).to eq('marketing')
        
        # 2回目：業界情報
        response2 = auto_conversation_service.process_message(
          conversation,
          'EC事業を運営しています'
        )
        
        # コンテキストを再構築
        context = context_service.build_context(conversation)
        entities = context_service.extract_entities([
          { content: 'EC事業を運営しています' }
        ])
        
        expect(conversation.metadata['collected_info']['business_type']).to eq('EC')
      end
    end
  end
  
  describe 'エンティティ抽出の精度' do
    it '複雑な文章から正確にエンティティを抽出する' do
      messages = [
        { 
          role: 'user', 
          content: '株式会社テストの山田と申します。弊社は月額200万円の予算でSEO対策とリスティング広告を検討しています。連絡先はyamada@test.co.jp、03-1234-5678です。'
        }
      ]
      
      entities = context_service.extract_entities(messages)
      
      expect(entities[:company_name]).to eq('株式会社テスト')
      expect(entities[:person_name]).to eq('山田')
      expect(entities[:budget]).to eq('月額200万円')
      expect(entities[:service]).to include('SEO対策')
      expect(entities[:service]).to include('リスティング広告')
      expect(entities[:email]).to eq('yamada@test.co.jp')
      expect(entities[:phone]).to eq('03-1234-5678')
    end
  end
end