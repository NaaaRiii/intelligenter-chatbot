# frozen_string_literal: true

# チャット画面のコントローラー
class ChatController < ApplicationController
  before_action :set_conversation

  def index
    @messages = @conversation&.messages&.chronological || []
    @current_user = User.first # 仮のユーザー（認証機能実装まで）
  end

  private

  def set_conversation
    @conversation = if params[:conversation_id]
                      Conversation.find_by(id: params[:conversation_id]) || create_new_conversation
                    else
                      create_new_conversation
                    end
  end

  def create_new_conversation
    user = User.first || User.create!(
      email: 'demo@example.com',
      name: 'Demo User'
    )
    user.conversations.create!(session_id: SecureRandom.uuid)
  end
end
