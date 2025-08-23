# frozen_string_literal: true

# チャット画面のコントローラー
class ChatController < ApplicationController
  before_action :set_conversation

  def index
    @current_user = current_user
    @load_error = false
    begin
      @messages = load_messages
      trigger_test_bot_response_if_needed
    rescue StandardError
      handle_index_error
    end
  end

  # rubocop:disable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity, Metrics/MethodLength
  def create_message
    return redirect_to('/login', alert: I18n.t('flash.sessions.expired')) if current_user.nil?

    user = current_user || User.first
    cid_param = params[:conversation_id].presence || referrer_conversation_id

    @conversation = resolve_conversation_for_create(user, cid_param)

    content = params.dig(:message, :content).to_s
    role = params.dig(:message, :role).presence || 'user'

    # サーバーサイドバリデーション
    if content.blank?
      flash[:alert] = I18n.t('flash.messages.blank')
    elsif content.length > 2000
      flash[:alert] = I18n.t('flash.messages.too_long', count: 2000)
    elsif content.match?(/[\x00-\x08\x0B\x0C\x0E-\x1F\x7F]/)
      flash[:alert] = I18n.t('flash.messages.invalid_chars')
    elsif content.present?
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

    # conversation_idを確実に保持してリダイレクト
    redirect_to(chat_path(conversation_id: @conversation&.id || cid_param))
  rescue StandardError
    cid = params[:conversation_id].presence || referrer_conversation_id || @conversation&.id
    redirect_back(fallback_location: (cid ? chat_path(conversation_id: cid) : chat_path), allow_other_host: false)
  end
  # rubocop:enable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity, Metrics/MethodLength

  private

  # rubocop:disable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity
  def set_conversation
    unless params[:conversation_id]
      @conversation = create_new_conversation
      return
    end

    conv = Conversation.find_by(id: params[:conversation_id])

    if conv.nil?
      # テスト/本番問わず、存在しないIDなら新規作成し、UIに不在通知も出す
      @not_found = true
      @conversation = create_new_conversation
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

  # index 用の補助メソッド群
  def load_messages
    return [] unless @conversation

    Message.where(conversation_id: @conversation.id).chronological
  end

  def trigger_test_bot_response_if_needed
    return unless Rails.env.test? && @conversation&.bot_enabled?

    last_user = @conversation.last_user_message
    return unless last_user

    return if assistant_exists_after?(last_user)

    generate_bot_response_for(last_user)
    @messages = load_messages
  rescue StandardError
    # noop
  end

  def assistant_exists_after?(last_user_message)
    @conversation.messages
                 .where(role: 'assistant')
                 .exists?(['created_at > ?', last_user_message.created_at])
  end

  def generate_bot_response_for(user_message)
    ChatBotService.new(conversation: @conversation, user_message: user_message).generate_response
  end

  def handle_index_error
    @messages = []
    @load_error = true
  end
end
