# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Api::V1::Conversations', type: :request do
  let(:user) { create(:user) }
  let(:headers) { { 'Authorization' => "Bearer #{user.api_token}" } }

  describe 'GET /api/v1/conversations' do
    let!(:conversations) { create_list(:conversation, 3, user: user) }

    it '会話一覧を取得できる' do
      get '/api/v1/conversations', headers: headers

      expect(response).to have_http_status(:ok)
      json = response.parsed_body
      expect(json['conversations'].size).to eq(3)
      expect(json['meta']).to include('current_page', 'total_pages', 'total_count')
    end

    it '認証なしではアクセスできない' do
      get '/api/v1/conversations'
      expect(response).to have_http_status(:unauthorized)
    end
  end

  describe 'GET /api/v1/conversations/:id' do
    let(:conversation) { create(:conversation, user: user) }
    let!(:messages) { create_list(:message, 5, conversation: conversation) }

    it '特定の会話を取得できる' do
      get "/api/v1/conversations/#{conversation.id}", headers: headers

      expect(response).to have_http_status(:ok)
      json = response.parsed_body
      expect(json['id']).to eq(conversation.id)
      expect(json['messages'].size).to eq(5)
    end

    it '他ユーザーの会話は取得できない' do
      other_conversation = create(:conversation)
      get "/api/v1/conversations/#{other_conversation.id}", headers: headers

      expect(response).to have_http_status(:not_found)
    end
  end

  describe 'POST /api/v1/conversations' do
    let(:valid_params) do
      {
        conversation: {
          session_id: 'test-session-123',
          metadata: { source: 'api_test' }
        }
      }
    end

    it '新しい会話を作成できる' do
      expect do
        post '/api/v1/conversations', params: valid_params, headers: headers
      end.to change(Conversation, :count).by(1)

      expect(response).to have_http_status(:created)
      json = response.parsed_body
      expect(json['session_id']).to eq('test-session-123')
    end

    it '無効なパラメータではエラーになる' do
      invalid_params = { conversation: { session_id: nil } }
      post '/api/v1/conversations', params: invalid_params, headers: headers

      expect(response).to have_http_status(:unprocessable_entity)
      json = response.parsed_body
      expect(json).to have_key('errors')
    end
  end

  describe 'PATCH /api/v1/conversations/:id' do
    let(:conversation) { create(:conversation, user: user) }
    let(:update_params) do
      {
        conversation: {
          metadata: { updated: true }
        }
      }
    end

    it '会話を更新できる' do
      patch "/api/v1/conversations/#{conversation.id}", params: update_params, headers: headers

      expect(response).to have_http_status(:ok)
      json = response.parsed_body
      expect(json['metadata']).to include('updated' => true)
    end
  end

  describe 'DELETE /api/v1/conversations/:id' do
    let!(:conversation) { create(:conversation, user: user) }

    it '会話を削除できる' do
      expect do
        delete "/api/v1/conversations/#{conversation.id}", headers: headers
      end.to change(Conversation, :count).by(-1)

      expect(response).to have_http_status(:no_content)
    end
  end
end
