# frozen_string_literal: true

require 'rails_helper'

RSpec.describe EscalationService do
  let(:service) { described_class.new }
  let(:conversation) { create(:conversation) }
  
  describe '#trigger_escalation' do
    context '情報収集完了時のエスカレーション' do
      let(:collected_info) do
        {
          'business_type' => '小売業',
          'budget_range' => '月額100万円',
          'current_tools' => 'Shopify, Google Analytics',
          'challenges' => 'CVR改善'
        }
      end
      
      let(:metadata) do
        {
          'category' => 'marketing',
          'collected_info' => collected_info,
          'ai_interaction_count' => 3,
          'urgency' => 'normal'
        }
      end
      
      it 'エスカレーション情報を生成する' do
        result = service.trigger_escalation(conversation, metadata)
        
        expect(result).to have_key(:success)
        expect(result[:success]).to be true
        expect(result).to have_key(:escalation_id)
        expect(result).to have_key(:message)
        expect(result).to have_key(:slack_notification)
      end
      
      it 'Slack通知用のメッセージを生成する' do
        result = service.trigger_escalation(conversation, metadata)
        
        slack_message = result[:slack_notification]
        expect(slack_message).to include('エスカレーション')
        expect(slack_message).to include('小売業')
        expect(slack_message).to include('100万円')
        expect(slack_message).to include('CVR改善')
      end
      
      it 'conversationのメタデータを更新する' do
        service.trigger_escalation(conversation, metadata)
        
        conversation.reload
        expect(conversation.metadata['escalation_required']).to be true
        expect(conversation.metadata['escalated_at']).not_to be_nil
        expect(conversation.metadata['escalation_status']).to eq('pending')
      end
    end
    
    context '緊急度による即時エスカレーション' do
      let(:metadata) do
        {
          'category' => 'tech',
          'urgency' => 'high',
          'collected_info' => {
            'system_type' => 'API',
            'error_details' => 'システム全体がダウン'
          },
          'ai_interaction_count' => 1
        }
      end
      
      it '緊急エスカレーションフラグを含める' do
        result = service.trigger_escalation(conversation, metadata)
        
        expect(result[:priority]).to eq('high')
        expect(result[:slack_notification]).to include('🚨 緊急')
        expect(result[:slack_notification]).to include('システム全体がダウン')
      end
      
      it '緊急連絡先への通知を含める' do
        result = service.trigger_escalation(conversation, metadata)
        
        expect(result[:notify_channels]).to include('#urgent-support')
        expect(result[:notify_users]).to include('@oncall')
      end
    end
    
    context 'カテゴリ別の通知先振り分け' do
      it 'マーケティング案件は#marketingチャンネルへ' do
        metadata = { 'category' => 'marketing', 'collected_info' => {} }
        result = service.trigger_escalation(conversation, metadata)
        
        expect(result[:target_channel]).to eq('#marketing')
      end
      
      it '技術案件は#tech-supportチャンネルへ' do
        metadata = { 'category' => 'tech', 'collected_info' => {} }
        result = service.trigger_escalation(conversation, metadata)
        
        expect(result[:target_channel]).to eq('#tech-support')
      end
      
      it '一般案件は#general-supportチャンネルへ' do
        metadata = { 'category' => 'general', 'collected_info' => {} }
        result = service.trigger_escalation(conversation, metadata)
        
        expect(result[:target_channel]).to eq('#general-support')
      end
    end
  end
  
  describe '#format_slack_message' do
    let(:collected_info) do
      {
        'business_type' => 'EC事業',
        'budget_range' => '月額50万円',
        'current_tools' => 'BASE',
        'challenges' => '売上向上'
      }
    end
    
    it 'Slack用のフォーマットされたメッセージを生成する' do
      message = service.format_slack_message(conversation, collected_info, 'marketing')
      
      expect(message).to have_key(:text)
      expect(message).to have_key(:attachments)
      
      attachment = message[:attachments].first
      expect(attachment[:color]).to eq('warning')
      expect(attachment[:fields]).to be_an(Array)
    end
    
    it '収集した情報をフィールドとして含める' do
      message = service.format_slack_message(conversation, collected_info, 'marketing')
      fields = message[:attachments].first[:fields]
      
      field_titles = fields.map { |f| f[:title] }
      expect(field_titles).to include('業界/事業')
      expect(field_titles).to include('予算')
      expect(field_titles).to include('利用ツール')
      expect(field_titles).to include('課題')
    end
    
    it '会話履歴へのリンクを含める' do
      message = service.format_slack_message(conversation, collected_info, 'marketing')
      
      expect(message[:attachments].first[:actions]).to be_an(Array)
      action = message[:attachments].first[:actions].first
      expect(action[:text]).to include('会話履歴')
      expect(action[:url]).to include("/conversations/#{conversation.id}")
    end
  end
  
  describe '#should_escalate?' do
    it '必要情報が全て揃ったらtrueを返す' do
      metadata = {
        'collected_info' => {
          'business_type' => '小売業',
          'budget_range' => '月額100万円',
          'current_tools' => 'Shopify'
        },
        'category' => 'marketing'
      }
      
      expect(service.should_escalate?(metadata)).to be true
    end
    
    it '5往復に達したらtrueを返す' do
      metadata = {
        'ai_interaction_count' => 5,
        'collected_info' => { 'business_type' => '小売業' }
      }
      
      expect(service.should_escalate?(metadata)).to be true
    end
    
    it '緊急度が高い場合はtrueを返す' do
      metadata = {
        'urgency' => 'high',
        'ai_interaction_count' => 1
      }
      
      expect(service.should_escalate?(metadata)).to be true
    end
    
    it 'エスカレーション済みの場合はfalseを返す' do
      metadata = {
        'escalation_required' => true,
        'escalated_at' => Time.current.iso8601
      }
      
      expect(service.should_escalate?(metadata)).to be false
    end
  end
  
  describe '#get_escalation_priority' do
    it '緊急度highは優先度highを返す' do
      metadata = { 'urgency' => 'high' }
      expect(service.get_escalation_priority(metadata)).to eq('high')
    end
    
    it '予算100万円以上は優先度mediumを返す' do
      metadata = {
        'collected_info' => { 'budget_range' => '月額200万円' },
        'urgency' => 'normal'
      }
      expect(service.get_escalation_priority(metadata)).to eq('medium')
    end
    
    it 'それ以外は優先度normalを返す' do
      metadata = {
        'collected_info' => { 'budget_range' => '月額30万円' },
        'urgency' => 'normal'
      }
      expect(service.get_escalation_priority(metadata)).to eq('normal')
    end
  end
end