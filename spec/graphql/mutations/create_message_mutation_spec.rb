# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'GraphQL CreateMessage Mutation', type: :request do
  let(:user) { create(:user) }
  let(:conversation) { create(:conversation, user: user) }
  let(:headers) { { 'Authorization' => "Bearer #{user.api_token}" } }

  describe 'createMessage mutation' do
    let(:mutation) do
      <<~GRAPHQL
        mutation CreateMessage($conversationId: ID!, $content: String!, $role: String!) {
          createMessage(input: {
            conversationId: $conversationId
            content: $content
            role: $role
          }) {
            message {
              id
              content
              role
            }
            errors
          }
        }
      GRAPHQL
    end

    it 'メッセージを作成できる' do
      vars = { conversationId: conversation.id, content: 'GraphQLテストメッセージ', role: 'user' }

      expect do
        post '/graphql', params: { query: mutation, variables: vars.to_json }, headers: headers
      end.to change(Message, :count).by(1)
      expect(ProcessAiResponseJob).to have_been_enqueued

      data = response.parsed_body.dig('data', 'createMessage')
      expect(data['message']).to include('content' => 'GraphQLテストメッセージ', 'role' => 'user')
      expect(data['errors']).to be_empty
    end

    it '無効なパラメータではエラーを返す' do
      variables = {
        conversationId: conversation.id,
        content: '',
        role: 'user'
      }

      post '/graphql', params: { query: mutation, variables: variables.to_json }, headers: headers

      expect(response).to have_http_status(:ok)
      data = response.parsed_body.dig('data', 'createMessage')

      expect(data['message']).to be_nil
      expect(data['errors']).not_to be_empty
    end
  end
end
