# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'AutoConversation Flow Integration' do
  let(:service) { AutoConversationService.new }
  let(:conversation) { create(:conversation) }
  
  describe '3-5往復での情報収集フロー' do
    context 'マーケティング相談の完全フロー' do
      it '3往復で必要情報（業界、予算、課題）を収集する' do
        # 往復1: 初回メッセージ → 業界を聞く
        initial_message = 'ECサイトの売上を改善したいです'
        result1 = service.process_initial_message(conversation, initial_message)
        
        expect(result1[:category]).to eq('marketing')
        expect(result1[:collected_info][:business_type]).to eq('EC')
        expect(result1[:next_question]).to match(/予算/)
        
        # 往復2: 予算回答 → 課題を聞く
        budget_response = '月額予算は100万円程度です'
        collected_info = result1[:collected_info]
        new_info = service.extract_information(budget_response, 'marketing')
        collected_info.merge!(new_info)
        
        expect(collected_info[:budget_range]).to match(/100万/)
        
        next_question = service.generate_next_question(collected_info, 'marketing')
        expect(next_question).to match(/ツール|システム/)
        
        # 往復3: ツール回答 → 必要情報が揃う
        tools_response = '現在はShopifyとGoogle Analyticsを使っています'
        new_info = service.extract_information(tools_response, 'marketing')
        collected_info.merge!(new_info)
        
        expect(collected_info[:current_tools]).to include('Shopify')
        expect(collected_info[:current_tools]).to include('Google Analytics')
        
        # 必須情報が全て揃ったか確認
        next_question = service.generate_next_question(collected_info, 'marketing')
        expect(next_question).to be_nil
        
        # サマリー生成を確認
        summary = service.generate_summary(collected_info, 'marketing')
        expect(summary).to include('EC')
        expect(summary).to include('100万')
        expect(summary).to include('Shopify')
      end
      
      it '複数情報を一度に提供した場合は2往復で完了する' do
        # 往復1: 複数情報を含む初回メッセージ
        initial_message = 'アパレルのECサイトを運営しており、月額予算は50万円です'
        result1 = service.process_initial_message(conversation, initial_message)
        
        expect(result1[:collected_info][:business_type]).to match(/アパレル|EC/)
        expect(result1[:collected_info][:budget_range]).to match(/50万/)
        expect(result1[:next_question]).to match(/ツール|システム/)
        
        # 往復2: 残りの情報を提供
        final_response = 'Shopifyを使っていて、CVR改善が課題です'
        collected_info = result1[:collected_info]
        new_info = service.extract_information(final_response, 'marketing')
        collected_info.merge!(new_info)
        
        expect(collected_info[:current_tools]).to include('Shopify')
        
        # 必要情報が揃ったので次の質問はnil
        next_question = service.generate_next_question(collected_info, 'marketing')
        expect(next_question).to be_nil
      end
      
      it '5往復を超えると自動的にエスカレーション' do
        metadata = {
          'ai_interaction_count' => 5,
          'collected_info' => {
            'business_type' => '小売業'
            # 他の情報は不足
          }
        }
        
        should_continue = service.should_continue_conversation?(metadata)
        expect(should_continue).to be false
        
        action = service.determine_next_action(metadata)
        expect(action).to eq(:escalate_to_human)
      end
    end
    
    context '技術サポートの情報収集フロー' do
      it '3往復で必要情報（システム、エラー詳細、発生時期）を収集する' do
        # 往復1: 初回メッセージ
        initial_message = 'APIエラーが発生しています'
        result1 = service.process_initial_message(conversation, initial_message)
        
        expect(result1[:category]).to eq('tech')
        expect(result1[:collected_info][:system_type]).to eq('API')
        expect(result1[:collected_info][:error_details]).to include('エラー')
        expect(result1[:next_question]).to match(/いつから|発生/)
        
        # 往復2: 発生時期を回答
        time_response = '昨日の午後3時頃から発生しています'
        collected_info = result1[:collected_info]
        collected_info['occurrence_time'] = '昨日の午後3時頃'
        
        # 往復3: 必要情報が揃う
        next_question = service.generate_next_question(collected_info, 'tech')
        expect(next_question).to be_nil
      end
    end
    
    context '情報収集の優先順位' do
      it '業界 → 予算 → ツール → 課題の順序で質問する' do
        collected_info = {}
        category = 'marketing'
        
        # 最初は業界を聞く
        question1 = service.generate_next_question(collected_info, category)
        expect(question1).to match(/業界|事業/)
        
        # 業界を入力したら予算を聞く
        collected_info['business_type'] = '小売業'
        question2 = service.generate_next_question(collected_info, category)
        expect(question2).to match(/予算|費用/)
        
        # 予算を入力したらツールを聞く
        collected_info['budget_range'] = '月額100万円'
        question3 = service.generate_next_question(collected_info, category)
        expect(question3).to match(/ツール|システム/)
        
        # 全て入力したら質問終了
        collected_info['current_tools'] = 'Shopify'
        question4 = service.generate_next_question(collected_info, category)
        expect(question4).to be_nil
      end
    end
    
    context 'メタデータ管理' do
      it '会話回数をカウントする' do
        metadata = { 'ai_interaction_count' => 0 }
        
        # 1回目
        metadata['ai_interaction_count'] += 1
        expect(service.should_continue_conversation?(metadata)).to be true
        
        # 2回目
        metadata['ai_interaction_count'] += 1
        expect(service.should_continue_conversation?(metadata)).to be true
        
        # 3回目（まだ継続可能）
        metadata['ai_interaction_count'] += 1
        expect(service.should_continue_conversation?(metadata)).to be false
        
        # 5回目（上限）
        metadata['ai_interaction_count'] = 5
        expect(service.should_continue_conversation?(metadata)).to be false
      end
      
      it '収集した情報をメタデータに保存する' do
        message = '小売業で月額予算100万円、Shopifyを使っています'
        extracted = service.extract_information(message, 'marketing')
        
        metadata = {
          'collected_info' => extracted,
          'category' => 'marketing',
          'ai_interaction_count' => 1
        }
        
        expect(metadata['collected_info'][:business_type]).to eq('小売業')
        expect(metadata['collected_info'][:budget_range]).to match(/100万/)
        expect(metadata['collected_info'][:current_tools]).to include('Shopify')
        
        # 必要情報が揃ったので継続不要
        expect(service.should_continue_conversation?(metadata)).to be false
      end
    end
    
    context '緊急度による制御' do
      it '緊急度が高い場合は即エスカレーション' do
        metadata = {
          'ai_interaction_count' => 1,
          'urgency' => 'high',
          'collected_info' => {}
        }
        
        expect(service.should_continue_conversation?(metadata)).to be false
        expect(service.determine_next_action(metadata)).to eq(:escalate_to_human)
      end
      
      it '通常の緊急度なら3往復まで継続' do
        metadata = {
          'ai_interaction_count' => 2,
          'urgency' => 'normal',
          'collected_info' => { 'business_type' => '小売業' }
        }
        
        expect(service.should_continue_conversation?(metadata)).to be true
        expect(service.determine_next_action(metadata)).to eq(:continue_conversation)
      end
    end
    
    context '文脈を考慮した応答生成' do
      let(:conversation_history) do
        [
          { role: 'user', content: 'ECサイトの改善をしたい' },
          { role: 'assistant', content: 'ECサイトの改善についてですね。業界を教えてください。' },
          { role: 'user', content: 'アパレル業界です' }
        ]
      end
      
      it '既に収集した情報は再度聞かない' do
        collected_info = { business_type: 'アパレル' }
        response = service.build_context_aware_response(
          conversation_history,
          collected_info,
          'marketing'
        )
        
        expect(response).not_to match(/業界/)
        expect(response).to match(/予算|ツール/)
      end
      
      it '収集済み情報を認識して返答する' do
        collected_info = { business_type: 'アパレル', budget_range: '月額50万円' }
        response = service.build_context_aware_response(
          conversation_history,
          collected_info,
          'marketing'
        )
        
        expect(response).to include('アパレル')
        expect(response).to match(/ツール|システム/)
      end
    end
  end
end