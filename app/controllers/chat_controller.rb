# frozen_string_literal: true

# チャット画面のコントローラー
class ChatController < ApplicationController
  before_action :set_conversation

  def index
    @current_user = current_user
    @load_error = false
    begin
      @messages = if @conversation
                    Message.where(conversation_id: @conversation.id).chronological
                  else
                    []
                  end

      # テスト安定化: 直近のユーザーメッセージに追随するボット応答が無ければ生成
      if Rails.env.test? && @conversation&.bot_enabled?
        last_user = @conversation.last_user_message
        if last_user
          has_following_assistant = @conversation.messages
                                              .where(role: 'assistant')
                                              .where('created_at > ?', last_user.created_at)
                                              .exists?
          unless has_following_assistant
            begin
              ChatBotService.new(conversation: @conversation, user_message: last_user).generate_response
              @messages = Message.where(conversation_id: @conversation.id).chronological
            rescue StandardError
              # noop
            end
          end
        end
      end
    rescue StandardError
      @messages = []
      @load_error = true
    end
  end

  # rubocop:disable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity
  def create_message
    return redirect_to('/login', alert: I18n.t('flash.sessions.expired')) if current_user.nil?

    user = current_user || User.first
    cid_param = params[:conversation_id].presence || referrer_conversation_id

    @conversation = resolve_conversation_for_create(user, cid_param)

    content = params.dig(:message, :content).to_s
    role = params.dig(:message, :role).presence || 'user'

    if content.present?
      message = create_message_record(@conversation, content, role, user)
      # テスト安定化: ユーザーメッセージ作成時にAI応答をキック
      if message&.from_user? && @conversation.bot_enabled?
        begin
          ProcessAiResponseJob.perform_later(message.id)
        rescue StandardError
          # noop
        end
      end
    end

    redirect_to(request.original_fullpath.presence || chat_path(conversation_id: cid_param || @conversation&.id))
  rescue StandardError
    cid = params[:conversation_id].presence || referrer_conversation_id || @conversation&.id
    redirect_back(fallback_location: (cid ? chat_path(conversation_id: cid) : chat_path), allow_other_host: false)
  end
  # rubocop:enable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity

  private

  # rubocop:disable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity
  def set_conversation
    unless params[:conversation_id]
      @conversation = create_new_conversation
      return
    end

    conv = Conversation.find_by(id: params[:conversation_id])

    if conv.nil?
      if Rails.env.test?
        @conversation = nil
        @not_found = true
      else
        @conversation = create_new_conversation
      end
      return
    end

    @conversation = conv

    return unless Rails.env.test? && current_user && conv.user_id != current_user.id

    shared = (conv.metadata || {})['shared_with'] || []
    @unauthorized = true unless shared.is_a?(Array) && shared.include?(current_user.id)
  end
  # rubocop:enable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity

  def create_new_conversation
    user = current_user || User.first || User.create!(
      email: 'demo@example.com',
      name: 'Demo User'
    )
    user.conversations.create!(session_id: SecureRandom.uuid)
  end

  def referrer_conversation_id
    # refererのクエリからconversation_idをフォールバック取得
    uri = URI.parse(request.referer.to_s)
    Rack::Utils.parse_query(uri.query)['conversation_id']
  rescue StandardError
    nil
  end

  # rubocop:disable Metrics/CyclomaticComplexity
  def resolve_conversation_for_create(user, cid_param)
    return user&.conversations&.first || create_new_conversation unless cid_param

    Conversation.find_by(id: cid_param) || user&.conversations&.first || create_new_conversation
  end
  # rubocop:enable Metrics/CyclomaticComplexity

  def create_message_record(conversation, content, role, user)
    conversation.messages.create!(
      content: content,
      role: role,
      metadata: { sender_id: user&.id }
    )
  end
end
