# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ConversationContextService do
  let(:service) { described_class.new }
  let(:conversation) { create(:conversation) }
  
  describe '#build_context' do
    context '会話の流れを構築' do
      before do
        # 過去のメッセージを作成
        create(:message, conversation: conversation, role: 'user', 
               content: 'マーケティングツールを探しています')
        create(:message, conversation: conversation, role: 'assistant',
               content: 'どのような業界でご利用予定ですか？')
        create(:message, conversation: conversation, role: 'user',
               content: 'EC事業を運営しています')
        create(:message, conversation: conversation, role: 'assistant',
               content: 'ご予算はどの程度をお考えですか？')
      end
      
      it '過去のメッセージから文脈を構築する' do
        context = service.build_context(conversation)
        
        expect(context).to have_key(:conversation_history)
        expect(context).to have_key(:summary)
        expect(context).to have_key(:key_points)
        expect(context).to have_key(:current_topic)
      end
      
      it '会話履歴を時系列順に整理する' do
        context = service.build_context(conversation)
        history = context[:conversation_history]
        
        expect(history).to be_an(Array)
        expect(history.first[:role]).to eq('user')
        expect(history.first[:content]).to include('マーケティングツール')
      end
      
      it '重要なキーポイントを抽出する' do
        context = service.build_context(conversation)
        key_points = context[:key_points]
        
        expect(key_points).to include('category' => 'marketing')
        expect(key_points).to include('business_type' => 'EC事業')
        expect(key_points).to include('topic' => 'ツール選定')
      end
      
      it '現在の話題を特定する' do
        context = service.build_context(conversation)
        
        expect(context[:current_topic]).to eq('予算確認')
      end
    end
    
    context '長い会話の要約' do
      before do
        # 10往復の会話を作成
        10.times do |i|
          create(:message, conversation: conversation, role: 'user',
                 content: "質問#{i + 1}：詳細について教えてください")
          create(:message, conversation: conversation, role: 'assistant',
                 content: "回答#{i + 1}：こちらが詳細です")
        end
      end
      
      it '長い会話を要約する' do
        context = service.build_context(conversation)
        
        expect(context[:summary]).to be_present
        expect(context[:summary].length).to be < 500
      end
      
      it '直近の5往復を重視する' do
        context = service.build_context(conversation)
        recent = context[:recent_messages]
        
        expect(recent.count).to eq(10) # 5往復 = 10メッセージ
        expect(recent.last[:content]).to include('回答10')
      end
    end
  end
  
  describe '#extract_entities' do
    it '会話から重要なエンティティを抽出する' do
      messages = [
        { role: 'user', content: '株式会社ABCの山田です。月額50万円でSEO対策を検討しています' }
      ]
      
      entities = service.extract_entities(messages)
      
      expect(entities[:company_name]).to eq('株式会社ABC')
      expect(entities[:person_name]).to eq('山田')
      expect(entities[:budget]).to eq('月額50万円')
      expect(entities[:service]).to include('SEO対策')
    end
    
    it 'メールアドレスと電話番号を抽出する' do
      messages = [
        { role: 'user', content: '連絡先は yamada@abc.com または 03-1234-5678 です' }
      ]
      
      entities = service.extract_entities(messages)
      
      expect(entities[:email]).to eq('yamada@abc.com')
      expect(entities[:phone]).to eq('03-1234-5678')
    end
  end
  
  describe '#determine_intent' do
    it '問い合わせの意図を判定する' do
      messages = [
        { role: 'user', content: 'ツールの料金について教えてください' }
      ]
      
      intent = service.determine_intent(messages)
      
      expect(intent[:type]).to eq('pricing_inquiry')
      expect(intent[:confidence]).to be > 0.7
    end
    
    it '複数の意図を検出する' do
      messages = [
        { role: 'user', content: 'デモを見たいです。また、他社との違いも知りたいです' }
      ]
      
      intent = service.determine_intent(messages)
      
      expect(intent[:primary]).to eq('comparison')
      expect(intent[:secondary]).to include('demo_request')
    end
  end
  
  describe '#get_relevant_context' do
    context '関連する過去の会話を取得' do
      let(:user) { create(:user) }
      let!(:old_conversation) do
        conv = create(:conversation, user: user, 
                     created_at: 1.week.ago)
        conv.metadata = { 
          'category' => 'marketing',
          'resolved' => true,
          'solution' => 'Google Ads導入'
        }
        conv.save!
        conv
      end
      
      let!(:current_conversation) do
        create(:conversation, user: user)
      end
      
      it '同じ顧客の過去の会話を取得する' do
        relevant = service.get_relevant_context(current_conversation)
        
        expect(relevant[:past_conversations]).to be_present
        expect(relevant[:past_conversations].first[:id]).to eq(old_conversation.id)
      end
      
      it '過去の解決策を参照する' do
        relevant = service.get_relevant_context(current_conversation)
        
        expect(relevant[:previous_solutions]).to include('Google Ads導入')
      end
    end
  end
  
  describe '#update_context' do
    it '新しいメッセージでコンテキストを更新する' do
      initial_context = {
        conversation_history: [],
        key_points: { 'category' => 'general' }
      }
      
      new_message = { role: 'user', content: '予算は100万円です' }
      
      updated = service.update_context(initial_context, new_message)
      
      expect(updated[:conversation_history]).to include(new_message)
      expect(updated[:key_points]['budget']).to eq('100万円')
    end
    
    it 'トピックの変化を検出する' do
      initial_context = {
        current_topic: '予算確認',
        conversation_history: []
      }
      
      new_message = { role: 'user', content: '技術的なサポートについて教えてください' }
      
      updated = service.update_context(initial_context, new_message)
      
      expect(updated[:current_topic]).to eq('技術サポート')
      expect(updated[:topic_changed]).to be true
    end
  end
  
  describe '#generate_summary' do
    it '会話履歴から簡潔な要約を生成する' do
      messages = [
        { role: 'user', content: 'ECサイトのマーケティングを強化したい' },
        { role: 'assistant', content: '承知いたしました。現在の課題を教えてください' },
        { role: 'user', content: 'CVRが低く、リピート率も悪い' },
        { role: 'assistant', content: 'MA導入をご検討されてはいかがでしょうか' }
      ]
      
      summary = service.generate_summary(messages)
      
      expect(summary).to include('ECサイト')
      expect(summary).to include('CVR')
      expect(summary).to include('MA導入')
      expect(summary.length).to be < 200
    end
  end
  
  describe '#calculate_context_relevance' do
    it 'コンテキストの関連性スコアを計算する' do
      context1 = { key_points: { 'category' => 'marketing', 'budget' => '100万円' } }
      context2 = { key_points: { 'category' => 'marketing', 'budget' => '150万円' } }
      
      score = service.calculate_context_relevance(context1, context2)
      
      expect(score).to be_between(0.0, 1.0)
      expect(score).to be > 0.5 # カテゴリが同じなので関連性は高い
    end
  end
end