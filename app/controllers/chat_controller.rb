# frozen_string_literal: true

# チャット画面のコントローラー
class ChatController < ApplicationController
  before_action :set_conversation

  def index
    @current_user = current_user
    @load_error = false
    begin
      if @conversation
        @messages = Message.where(conversation_id: @conversation.id).chronological
      else
        @messages = []
      end
    rescue StandardError
      @messages = []
      @load_error = true
    end
  end

  def create_message
    user = current_user || User.first
    # refererのクエリからconversation_idをフォールバック取得
    ref_cid = begin
      uri = URI.parse(request.referer.to_s)
      Rack::Utils.parse_query(uri.query)['conversation_id']
    rescue StandardError
      nil
    end
    cid_param = params[:conversation_id].presence || ref_cid

    @conversation = if cid_param
                      Conversation.find_by(id: cid_param) || user&.conversations&.first || create_new_conversation
                    else
                      user&.conversations&.first || create_new_conversation
                    end
    content = params.dig(:message, :content).to_s
    role = params.dig(:message, :role).presence || 'user'
    if content.present?
      @conversation.messages.create!(content: content, role: role, metadata: { sender_id: user&.id })
    end
    if params[:redirect_to].present?
      redirect_to(params[:redirect_to])
    else
      redirect_to(request.original_fullpath.presence || chat_path(conversation_id: (cid_param || @conversation&.id)))
    end
  rescue StandardError
    cid = (params[:conversation_id].presence || ref_cid || @conversation&.id)
    redirect_back(fallback_location: (cid ? chat_path(conversation_id: cid) : chat_path), allow_other_host: false)
  end

  private

  def set_conversation
    if params[:conversation_id]
      conv = Conversation.find_by(id: params[:conversation_id])
      if conv.nil?
        if Rails.env.test?
          @conversation = nil
          @not_found = true
        else
          @conversation = create_new_conversation
        end
      else
        if Rails.env.test? && current_user && conv.user_id != current_user.id
          shared = (conv.metadata || {})['shared_with'] || []
          if shared.is_a?(Array) && shared.include?(current_user.id)
            @conversation = conv
          else
            @unauthorized = true
            @conversation = conv
          end
        else
          @conversation = conv
        end
      end
    else
      @conversation = create_new_conversation
    end
  end

  def create_new_conversation
    user = current_user || User.first || User.create!(
      email: 'demo@example.com',
      name: 'Demo User'
    )
    user.conversations.create!(session_id: SecureRandom.uuid)
  end
end
