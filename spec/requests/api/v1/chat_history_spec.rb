require 'rails_helper'

RSpec.describe 'Api::V1::ChatHistory', type: :request do
  let(:session_id) { SecureRandom.uuid }
  let(:headers) { { 'X-Session-Id' => session_id, 'Content-Type' => 'application/json' } }

  describe 'GET /api/v1/conversations' do
    context 'セッションIDに紐づく会話がある場合' do
      let!(:user_conversations) do
        3.times.map do |i|
          conversation = create(:conversation, 
            session_id: session_id,
            created_at: i.days.ago,
            updated_at: i.hours.ago
          )
          
          # 各会話にメッセージを追加
          create(:message, 
            conversation: conversation,
            role: 'user',
            content: "質問#{i}"
          )
          create(:message,
            conversation: conversation,
            role: 'assistant',
            content: "回答#{i}"
          )
          
          conversation
        end
      end

      let!(:other_conversation) do
        # 他のセッションの会話（表示されないべき）
        create(:conversation, session_id: SecureRandom.uuid)
      end

      it 'セッションIDに紐づく会話のみを返す' do
        get '/api/v1/conversations', headers: headers
        
        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)
        
        expect(json['conversations'].length).to eq(3)
        conversation_ids = json['conversations'].map { |c| c['id'] }
        expect(conversation_ids).not_to include(other_conversation.id)
      end

      it '会話は更新日時の降順で返される' do
        get '/api/v1/conversations', headers: headers
        
        json = JSON.parse(response.body)
        updated_times = json['conversations'].map { |c| Time.parse(c['updated_at']) }
        
        expect(updated_times).to eq(updated_times.sort.reverse)
      end

      it '各会話のメッセージが含まれる' do
        get '/api/v1/conversations', headers: headers
        
        json = JSON.parse(response.body)
        first_conversation = json['conversations'].first
        
        expect(first_conversation['messages']).to be_present
        expect(first_conversation['messages'].length).to eq(2)
        
        messages = first_conversation['messages']
        expect(messages.any? { |m| m['role'] == 'user' }).to be true
        expect(messages.any? { |m| m['role'] == 'assistant' }).to be true
      end
    end

    context 'セッションIDに紐づく会話がない場合' do
      it '空の配列を返す' do
        get '/api/v1/conversations', headers: headers
        
        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)
        
        expect(json['conversations']).to eq([])
      end
    end

    context 'セッションIDが提供されない場合' do
      it '新しいセッションIDを生成して空の配列を返す' do
        get '/api/v1/conversations', headers: headers.except('X-Session-Id')
        
        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)
        
        expect(json['conversations']).to eq([])
        expect(response.cookies['session_id']).to be_present
      end
    end

    context 'ページネーション' do
      before do
        10.times do |i|
          conversation = create(:conversation, 
            session_id: session_id,
            created_at: i.days.ago
          )
          create(:message, conversation: conversation, role: 'user')
        end
      end

      it 'ページネーションパラメータが動作する' do
        get '/api/v1/conversations?page=1&per_page=5', headers: headers
        
        json = JSON.parse(response.body)
        expect(json['conversations'].length).to eq(5)
        expect(json['meta']['total_count']).to eq(10)
        expect(json['meta']['total_pages']).to eq(2)
        expect(json['meta']['current_page']).to eq(1)
      end
    end
  end

  describe 'GET /api/v1/conversations/:id' do
    let(:conversation) { create(:conversation, session_id: session_id) }
    let!(:messages) do
      [
        create(:message, conversation: conversation, role: 'user', content: 'ユーザーメッセージ'),
        create(:message, conversation: conversation, role: 'assistant', content: 'アシスタント返信'),
        create(:message, conversation: conversation, role: 'company', content: '企業からの返信')
      ]
    end

    context '自分のセッションの会話の場合' do
      it '会話の詳細を取得できる' do
        get "/api/v1/conversations/#{conversation.id}", headers: headers
        
        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)
        
        expect(json['conversation']['id']).to eq(conversation.id)
        expect(json['conversation']['messages'].length).to eq(3)
        
        # 全てのロールのメッセージが含まれることを確認
        roles = json['conversation']['messages'].map { |m| m['role'] }
        expect(roles).to include('user', 'assistant', 'company')
      end
    end

    context '他のセッションの会話の場合' do
      let(:other_conversation) { create(:conversation, session_id: SecureRandom.uuid) }

      it '404を返す' do
        get "/api/v1/conversations/#{other_conversation.id}", headers: headers
        
        expect(response).to have_http_status(:not_found)
      end
    end
  end

  describe 'POST /api/v1/conversations/:id/resume' do
    let(:conversation) { create(:conversation, session_id: session_id, status: 'inactive') }
    
    context '会話の再開' do
      it '会話のステータスをactiveに変更する' do
        post "/api/v1/conversations/#{conversation.id}/resume", headers: headers
        
        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)
        
        expect(json['conversation']['status']).to eq('active')
        expect(conversation.reload.status).to eq('active')
      end

      it '最終更新日時を更新する' do
        old_updated_at = conversation.updated_at
        
        travel 1.minute do
          post "/api/v1/conversations/#{conversation.id}/resume", headers: headers
          
          expect(conversation.reload.updated_at).to be > old_updated_at
        end
      end
    end

    context '他のセッションの会話の場合' do
      let(:other_conversation) { create(:conversation, session_id: SecureRandom.uuid) }

      it '404を返す' do
        post "/api/v1/conversations/#{other_conversation.id}/resume", headers: headers
        
        expect(response).to have_http_status(:not_found)
      end
    end
  end
end