# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Chats', type: :request do
  describe 'GET /chat' do
    it 'チャット画面を表示する' do
      get chat_path
      expect(response).to have_http_status(:success)
    end

    it '新しい会話を作成する' do
      expect do
        get chat_path
      end.to change(Conversation, :count).by(1)
    end

    it 'ユーザーが存在しない場合はデモユーザーを作成する' do
      User.destroy_all
      expect do
        get chat_path
      end.to change(User, :count).by(1)
    end
  end

  describe 'GET /chat/:conversation_id' do
    let(:user) { create(:user) }
    let(:conversation) { create(:conversation, user: user) }

    before { create_list(:message, 3, conversation: conversation) }

    it '指定された会話を表示する' do
      get conversation_chat_path(conversation)
      expect(response).to have_http_status(:success)
    end

    it '存在しない会話IDの場合は新しい会話を作成する' do
      expect do
        get conversation_chat_path(id: 999_999)
      end.to change(Conversation, :count).by(1)
    end
  end
end
