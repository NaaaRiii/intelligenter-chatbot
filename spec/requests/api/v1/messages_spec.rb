# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Api::V1::Messages', type: :request do
  let(:user) { create(:user) }
  let(:conversation) { create(:conversation, user: user) }
  let(:headers) { { 'Authorization' => "Bearer #{user.api_token}" } }

  describe 'GET /api/v1/conversations/:conversation_id/messages' do
    let!(:messages) { create_list(:message, 10, conversation: conversation) }

    it 'メッセージ一覧を取得できる' do
      get "/api/v1/conversations/#{conversation.id}/messages", headers: headers

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json['messages'].size).to eq(10)
      expect(json['meta']).to include('current_page', 'total_pages')
    end
  end

  describe 'GET /api/v1/conversations/:conversation_id/messages/:id' do
    let(:message) { create(:message, conversation: conversation) }

    it '特定のメッセージを取得できる' do
      get "/api/v1/conversations/#{conversation.id}/messages/#{message.id}", headers: headers

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json['id']).to eq(message.id)
      expect(json['content']).to eq(message.content)
    end
  end

  describe 'POST /api/v1/conversations/:conversation_id/messages' do
    let(:valid_params) do
      {
        message: {
          content: 'テストメッセージです',
          role: 'user'
        }
      }
    end

    it '新しいメッセージを作成できる' do
      expect do
        post "/api/v1/conversations/#{conversation.id}/messages", 
             params: valid_params, 
             headers: headers
      end.to change(Message, :count).by(1)
                .and have_enqueued_job(ProcessAiResponseJob)

      expect(response).to have_http_status(:created)
      json = JSON.parse(response.body)
      expect(json['content']).to eq('テストメッセージです')
      expect(json['role']).to eq('user')
    end

    it '無効なパラメータではエラーになる' do
      invalid_params = { message: { content: '', role: 'user' } }
      post "/api/v1/conversations/#{conversation.id}/messages", 
           params: invalid_params, 
           headers: headers

      expect(response).to have_http_status(:unprocessable_entity)
      json = JSON.parse(response.body)
      expect(json).to have_key('errors')
    end
  end

  describe 'PATCH /api/v1/conversations/:conversation_id/messages/:id' do
    let(:message) { create(:message, conversation: conversation) }
    let(:update_params) do
      {
        message: {
          content: '更新されたメッセージ'
        }
      }
    end

    it 'メッセージを更新できる' do
      patch "/api/v1/conversations/#{conversation.id}/messages/#{message.id}", 
            params: update_params, 
            headers: headers

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json['content']).to eq('更新されたメッセージ')
    end
  end

  describe 'DELETE /api/v1/conversations/:conversation_id/messages/:id' do
    let!(:message) { create(:message, conversation: conversation) }

    it 'メッセージを削除できる' do
      expect do
        delete "/api/v1/conversations/#{conversation.id}/messages/#{message.id}", 
               headers: headers
      end.to change(Message, :count).by(-1)

      expect(response).to have_http_status(:no_content)
    end
  end
end