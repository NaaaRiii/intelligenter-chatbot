# frozen_string_literal: true

require 'rails_helper'

RSpec.describe SlackNotifier do
  let(:notifier) { described_class.new }
  
  describe '#send_notification' do
    let(:message) do
      {
        text: 'エスカレーション通知',
        attachments: [
          {
            color: 'warning',
            fields: [
              { title: '顧客', value: '山田太郎' },
              { title: '会社', value: '株式会社ABC' }
            ]
          }
        ]
      }
    end
    
    context 'Webhook送信' do
      it '指定チャンネルにメッセージを送信する' do
        stub_request(:post, /hooks\.slack\.com/)
          .to_return(status: 200, body: 'ok')
        
        result = notifier.send_notification('#marketing', message)
        
        expect(result[:success]).to be true
        expect(result[:response]).to eq('ok')
      end
      
      it 'エラー時はfalseを返す' do
        stub_request(:post, /hooks\.slack\.com/)
          .to_return(status: 404, body: 'invalid_token')
        
        result = notifier.send_notification('#marketing', message)
        
        expect(result[:success]).to be false
        expect(result[:error]).to include('invalid_token')
      end
      
      it 'ネットワークエラーをハンドリングする' do
        stub_request(:post, /hooks\.slack\.com/)
          .to_timeout
        
        result = notifier.send_notification('#marketing', message)
        
        expect(result[:success]).to be false
        expect(result[:error]).to include('timeout')
      end
    end
    
    context 'チャンネル別WebhookURL' do
      it 'マーケティングチャンネル用のURLを使用する' do
        stub = stub_request(:post, /hooks\.slack\.com.*marketing/)
          .to_return(status: 200, body: 'ok')
        
        notifier.send_notification('#marketing', message)
        
        expect(stub).to have_been_requested
      end
      
      it '技術サポートチャンネル用のURLを使用する' do
        stub = stub_request(:post, /hooks\.slack\.com.*tech/)
          .to_return(status: 200, body: 'ok')
        
        notifier.send_notification('#tech-support', message)
        
        expect(stub).to have_been_requested
      end
      
      it 'デフォルトチャンネルにフォールバックする' do
        stub = stub_request(:post, /hooks\.slack\.com/)
          .to_return(status: 200, body: 'ok')
        
        result = notifier.send_notification('#unknown', message)
        
        expect(result[:success]).to be true
        expect(stub).to have_been_requested
      end
    end
  end
  
  describe '#format_escalation_message' do
    let(:escalation_data) do
      {
        conversation_id: 123,
        category: 'marketing',
        collected_info: {
          'business_type' => '小売業',
          'budget_range' => '月額100万円',
          'challenges' => 'CVR改善'
        },
        priority: 'medium',
        escalation_reason: '情報収集完了'
      }
    end
    
    it 'エスカレーション用のリッチメッセージを生成する' do
      message = notifier.format_escalation_message(escalation_data)
      
      expect(message[:text]).to include('新規エスカレーション')
      expect(message[:attachments]).to be_present
      
      attachment = message[:attachments].first
      expect(attachment[:title]).to include('マーケティング')
      expect(attachment[:color]).to eq('warning')
    end
    
    it '優先度に応じて色を変更する' do
      high_priority = escalation_data.merge(priority: 'high')
      message = notifier.format_escalation_message(high_priority)
      
      expect(message[:attachments].first[:color]).to eq('danger')
      expect(message[:text]).to include('🚨')
    end
    
    it '会話IDとダッシュボードリンクを含める' do
      message = notifier.format_escalation_message(escalation_data)
      attachment = message[:attachments].first
      
      expect(attachment[:footer]).to include('ID: 123')
      expect(attachment[:actions]).to be_present
      
      action = attachment[:actions].first
      expect(action[:type]).to eq('button')
      expect(action[:text]).to include('ダッシュボード')
      expect(action[:url]).to include('/dashboard')
    end
  end
  
  describe '#test_connection' do
    it 'Webhook URLの有効性をテストする' do
      stub_request(:post, /hooks\.slack\.com/)
        .with(body: { text: 'Connection test' }.to_json)
        .to_return(status: 200, body: 'ok')
      
      result = notifier.test_connection('#marketing')
      
      expect(result[:success]).to be true
      expect(result[:message]).to include('正常に接続')
    end
    
    it '無効なURLを検出する' do
      stub_request(:post, /hooks\.slack\.com/)
        .to_return(status: 404, body: 'no_service')
      
      result = notifier.test_connection('#marketing')
      
      expect(result[:success]).to be false
      expect(result[:message]).to include('無効なWebhook')
    end
  end
end