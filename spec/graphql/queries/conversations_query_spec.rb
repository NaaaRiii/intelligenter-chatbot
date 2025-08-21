# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'GraphQL Conversations Query', type: :request do
  let(:user) { create(:user) }
  let(:headers) { { 'Authorization' => "Bearer #{user.api_token}" } }

  describe 'conversations query' do
    let!(:conversations) { create_list(:conversation, 3, user: user) }

    let(:query) do
      <<~GRAPHQL
        query {
          conversations {
            id
            sessionId
            isActive
            messageCount
          }
        }
      GRAPHQL
    end

    it '会話一覧を取得できる' do
      post '/graphql', params: { query: query }, headers: headers

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      data = json['data']['conversations']

      expect(data.size).to eq(3)
      expect(data.first).to include('id', 'sessionId', 'isActive', 'messageCount')
    end
  end

  describe 'conversation query' do
    let(:conversation) { create(:conversation, user: user) }
    let!(:messages) { create_list(:message, 3, conversation: conversation) }

    let(:query) do
      <<~GRAPHQL
        query GetConversation($id: ID!) {
          conversation(id: $id) {
            id
            sessionId
            messages {
              id
              content
              role
            }
          }
        }
      GRAPHQL
    end

    it '特定の会話を取得できる' do
      variables = { id: conversation.id }
      post '/graphql', params: { query: query, variables: variables.to_json }, headers: headers

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      data = json['data']['conversation']

      expect(data['id']).to eq(conversation.id.to_s)
      expect(data['messages'].size).to eq(3)
    end
  end
end
