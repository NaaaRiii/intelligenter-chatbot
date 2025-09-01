# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'エスカレーションフロー統合テスト', type: :integration do
  let(:conversation) { create(:conversation) }
  let(:auto_conversation_service) { AutoConversationService.new }
  let(:escalation_service) { EscalationService.new }
  let(:slack_notifier) { SlackNotifier.new }
  
  describe '情報収集完了からエスカレーションまでの流れ' do
    before do
      # Slack Webhook URLのモック
      stub_request(:post, /hooks\.slack\.com/)
        .to_return(status: 200, body: 'ok')
    end
    
    context 'マーケティング案件の場合' do
      it '必要情報収集後に自動的にエスカレーションする' do
        # 初回メッセージ処理
        initial_message = 'Webマーケティングツールの導入を検討しています'
        response1 = auto_conversation_service.process_message(
          conversation,
          initial_message
        )
        
        expect(response1[:auto_response]).to include('業界')
        expect(conversation.reload.metadata['category']).to eq('marketing')
        
        # 2回目：業界情報提供
        message2 = 'EC事業を運営しています'
        response2 = auto_conversation_service.process_message(
          conversation,
          message2
        )
        
        expect(response2[:auto_response]).to include('予算')
        expect(conversation.reload.metadata['collected_info']['business_type']).to eq('EC')
        
        # 3回目：予算情報提供
        message3 = '月額100万円程度で考えています'
        response3 = auto_conversation_service.process_message(
          conversation,
          message3
        )
        
        expect(response3[:auto_response]).to be_present
        expect(conversation.reload.metadata['collected_info']['budget_range']).to eq('月額100万円')
        
        # 4回目：ツール情報提供（最後の必要情報）
        message4 = '現在はShopifyとGoogle Analyticsを使っています。CVR改善とリピート率向上が主な課題です'
        response4 = auto_conversation_service.process_message(
          conversation,
          message4
        )
        
        # 必要情報が揃ったのでエスカレーション
        metadata = conversation.reload.metadata
        expect(metadata['escalation_required']).to be true
        expect(metadata['escalated_at']).not_to be_nil
        expect(metadata['escalation_id']).to match(/^ESC-\d{8}-[A-F0-9]+$/)
      end
    end
    
    context '緊急案件の場合' do
      it '緊急度高と判定したら即座にエスカレーションする' do
        # 緊急メッセージ
        urgent_message = 'システムが完全にダウンしていて、業務が止まっています！至急対応お願いします！'
        
        response = auto_conversation_service.process_message(
          conversation,
          urgent_message
        )
        
        # 即座にエスカレーション
        metadata = conversation.reload.metadata
        expect(metadata['urgency']).to eq('high')
        expect(metadata['escalation_required']).to be true
        expect(metadata['escalated_at']).not_to be_nil
      end
    end
    
    context '5往復制限' do
      it '5往復に達したらエスカレーションする' do
        messages = [
          'ツールについて相談したい',
          '小売業です',
          '予算はまだ未定です',
          'いろいろ課題があります',
          'もう少し詳しく教えてください'
        ]
        
        messages.each_with_index do |message, index|
          response = auto_conversation_service.process_message(
            conversation,
            message
          )
          
          if index < 4
            # 5往復未満は会話継続
            expect(response[:continue_conversation]).to be true
          else
            # 5往復でエスカレーション
            metadata = conversation.reload.metadata
            expect(metadata['ai_interaction_count']).to eq(5)
            expect(metadata['escalation_required']).to be true
          end
        end
      end
    end
  end
  
  describe 'Slack通知の内容検証' do
    before do
      # Slack Webhook URLのモック
      stub_request(:post, /hooks\.slack\.com/)
        .to_return(status: 200, body: 'ok')
    end
    
    let(:collected_info) do
      {
        'business_type' => '小売業',
        'budget_range' => '月額200万円',
        'current_tools' => 'Shopify, Google Analytics',
        'challenges' => 'CVR改善とリピート率向上'
      }
    end
    
    let(:metadata) do
      {
        'category' => 'marketing',
        'collected_info' => collected_info,
        'urgency' => 'medium',
        'ai_interaction_count' => 3
      }
    end
    
    it 'エスカレーション時のSlack通知メッセージが正しく生成される' do
      # エスカレーション実行
      result = escalation_service.trigger_escalation(conversation, metadata)
      
      expect(result[:success]).to be true
      expect(result[:escalation_id]).to be_present
      expect(result[:priority]).to eq('medium')
      expect(result[:target_channel]).to eq('#marketing')
      
      # Slack通知メッセージの検証
      slack_notification = result[:slack_notification]
      expect(slack_notification).to include('エスカレーション')
      expect(slack_notification).to include('小売業')
      expect(slack_notification).to include('200万円')
      expect(slack_notification).to include('CVR改善')
    end
    
    it '緊急案件の場合は追加の通知先が設定される' do
      urgent_metadata = metadata.merge('urgency' => 'high')
      
      result = escalation_service.trigger_escalation(conversation, urgent_metadata)
      
      expect(result[:priority]).to eq('high')
      expect(result[:notify_channels]).to include('#urgent-support')
      expect(result[:notify_users]).to include('@oncall')
      expect(result[:slack_notification]).to include('🚨 緊急')
    end
  end
  
  describe 'エンドツーエンドフロー' do
    before do
      # Slack Webhook URLのモック
      stub_request(:post, /hooks\.slack\.com/)
        .to_return(status: 200, body: 'ok')
    end
    
    it '初回メッセージから情報収集、エスカレーション、Slack通知までの完全フロー' do
      # 1. 初回メッセージ
      initial_response = auto_conversation_service.process_message(
        conversation,
        'マーケティングツールの導入を検討しています'
      )
      
      expect(initial_response[:continue_conversation]).to be true
      expect(initial_response[:auto_response]).to be_present
      
      # 2. 業界情報
      response2 = auto_conversation_service.process_message(
        conversation,
        'BtoB SaaS企業です'
      )
      
      expect(response2[:continue_conversation]).to be true
      
      # 3. 予算情報
      response3 = auto_conversation_service.process_message(
        conversation,
        '月額150万円を想定しています'
      )
      
      expect(response3[:continue_conversation]).to be true
      
      # 4. ツール情報（最後の必要情報）
      response4 = auto_conversation_service.process_message(
        conversation,
        'Google AnalyticsとHubSpotを使っています。リード獲得の効率化が主な課題です'
      )
      
      # エスカレーションが発生
      metadata = conversation.reload.metadata
      expect(metadata['escalation_required']).to be true
      expect(metadata['escalation_status']).to eq('pending')
      
      # 収集された情報の確認
      collected_info = metadata['collected_info']
      expect(collected_info['business_type']).to include('SaaS')
      expect(collected_info['budget_range']).to eq('月額150万円')
      expect(collected_info['current_tools']).to be_present
      
      # Slack通知が送信されたことを確認
      expect(WebMock).to have_requested(:post, /hooks\.slack\.com/).at_least_once
    end
  end
  
  describe 'エラーハンドリング' do
    it 'Slack通知失敗時でもエスカレーション情報は保存される' do
      # Slack APIエラーをモック
      stub_request(:post, /hooks\.slack\.com/)
        .to_return(status: 404, body: 'invalid_token')
      
      metadata = {
        'category' => 'marketing',
        'collected_info' => {
          'business_type' => '小売業',
          'budget_range' => '月額50万円'
        }
      }
      
      result = escalation_service.trigger_escalation(conversation, metadata)
      
      # エスカレーション自体は成功
      expect(result[:success]).to be true
      
      # メタデータは更新される
      updated_metadata = conversation.reload.metadata
      expect(updated_metadata['escalation_required']).to be true
      expect(updated_metadata['escalation_id']).to be_present
    end
    
    it '既にエスカレーション済みの場合は重複エスカレーションしない' do
      metadata = {
        'escalation_required' => true,
        'escalated_at' => Time.current.iso8601,
        'category' => 'marketing'
      }
      
      result = escalation_service.trigger_escalation(conversation, metadata)
      
      expect(result[:success]).to be false
      expect(result[:error]).to eq('Already escalated')
    end
  end
end