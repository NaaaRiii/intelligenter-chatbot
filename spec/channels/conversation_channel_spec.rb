require 'rails_helper'

RSpec.describe ConversationChannel, type: :channel do
  let(:session_id) { SecureRandom.uuid }
  let(:conversation) { create(:conversation, session_id: session_id) }

  before do
    # セッションIDをスタブ
    stub_connection session_id: session_id
  end

  describe '#subscribed' do
    context '会話IDが指定されている場合' do
      it '指定された会話にサブスクライブする' do
        subscribe(conversation_id: conversation.id)
        expect(subscription).to be_confirmed
        expect(subscription).to have_stream_for(conversation)
      end
    end

    context '会話IDが指定されていない場合' do
      it '新しい会話を作成してサブスクライブする' do
        subscribe
        expect(subscription).to be_confirmed
        expect(Conversation.where(session_id: session_id)).to exist
      end
    end
  end

  describe '#send_message' do
    before do
      subscribe(conversation_id: conversation.id)
    end

    context 'ユーザーメッセージの場合' do
      it 'メッセージを保存してブロードキャストする' do
        expect {
          perform :send_message, {
            'content' => 'テストメッセージ',
            'role' => 'user',
            'metadata' => { 'test' => 'data' }
          }
        }.to change { conversation.messages.count }.by(1)
        
        message = conversation.messages.last
        expect(message.content).to eq('テストメッセージ')
        expect(message.role).to eq('user')
        expect(message.metadata['test']).to eq('data')
      end

      it 'アシスタント応答ジョブをキューに入れる' do
        expect {
          perform :send_message, {
            'content' => 'テストメッセージ',
            'role' => 'user'
          }
        }.to have_enqueued_job(GenerateAssistantResponseJob)
      end
    end

    context '企業メッセージの場合' do
      it 'メッセージを保存してブロードキャストする' do
        expect {
          perform :send_message, {
            'content' => '企業からの返信',
            'role' => 'company',
            'metadata' => { 'sender' => 'support' }
          }
        }.to change { conversation.messages.count }.by(1)
        
        message = conversation.messages.last
        expect(message.content).to eq('企業からの返信')
        expect(message.role).to eq('company')
      end

      it 'アシスタント応答ジョブはキューに入れない' do
        expect {
          perform :send_message, {
            'content' => '企業からの返信',
            'role' => 'company'
          }
        }.not_to have_enqueued_job(GenerateAssistantResponseJob)
      end
    end

    it 'すべての購読者にメッセージをブロードキャストする' do
      expect {
        perform :send_message, {
          'content' => 'ブロードキャストテスト',
          'role' => 'user'
        }
      }.to have_broadcasted_to(conversation).with { |data|
        expect(data[:message][:content]).to eq('ブロードキャストテスト')
        expect(data[:message][:role]).to eq('user')
      }
    end
  end

  describe '#unsubscribed' do
    it 'サブスクリプションを停止する' do
      subscribe(conversation_id: conversation.id)
      expect(subscription).to be_confirmed
      
      unsubscribe
      expect(subscription).not_to be_confirmed
    end
  end
end