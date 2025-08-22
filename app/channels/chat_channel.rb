class ChatChannel < ApplicationCable::Channel
  def subscribed
    # 会話IDを元にストリームを購読
    return reject if params[:conversation_id].blank?

    @conversation = Conversation.find_by(id: params[:conversation_id])
    return reject unless @conversation && authorized?

    stream_from channel_name
    broadcast_user_connected
  end

  def unsubscribed
    # 切断通知
    if @conversation
      ActionCable.server.broadcast(
        channel_name,
        {
          type: 'user_disconnected',
          user: current_user.slice(:id, :name, :email),
          timestamp: Time.current
        }
      )
    end

    stop_all_streams
  end

  # メッセージ送信アクション
  def send_message(data)
    return unless @conversation && authorized?

    message = build_user_message(data)
    handle_message_save(message)
  end

  # タイピング通知
  def typing(data)
    return unless @conversation && authorized?

    ActionCable.server.broadcast(
      channel_name,
      {
        type: 'typing',
        user: current_user.slice(:id, :name),
        is_typing: data['is_typing']
      }
    )
  end

  # 既読通知
  def mark_as_read(data)
    return unless @conversation && authorized?
    return if data['message_id'].blank?

    message = @conversation.messages.find_by(id: data['message_id'])
    return unless message

    update_message_read_status(message)
    broadcast_message_read(message)
  end

  private

  def channel_name
    "conversation_#{@conversation.id}"
  end

  def authorized?
    # ユーザーがこの会話に参加できるか確認
    @conversation.user_id == current_user.id || current_user.admin?
  rescue StandardError
    false
  end

  def broadcast_message(message)
    ActionCable.server.broadcast(
      channel_name,
      {
        type: 'new_message',
        message: {
          id: message.id,
          content: message.content,
          role: message.role,
          created_at: message.created_at,
          user: current_user.slice(:id, :name, :email)
        }
      }
    )
  end

  def should_process_ai_response?
    # 最後のメッセージがユーザーからの場合のみAI応答を生成
    @conversation.messages.last&.from_user?
  end

  def broadcast_user_connected
    ActionCable.server.broadcast(
      channel_name,
      {
        type: 'user_connected',
        user: current_user.slice(:id, :name, :email),
        timestamp: Time.current
      }
    )
  end

  def build_user_message(data)
    @conversation.messages.build(
      content: data['content'],
      role: 'user',
      metadata: {
        sender_id: current_user.id,
        sent_at: Time.current
      }
    )
  end

  def handle_message_save(message)
    if message.save
      broadcast_message(message)
      trigger_bot_response(message) if should_trigger_bot_response?(message)
    else
      transmit_error(message)
    end
  end

  def should_trigger_bot_response?(message)
    # ユーザーメッセージの場合のみボット応答をトリガー
    message.role == 'user' && @conversation.bot_enabled?
  end

  def trigger_bot_response(message)
    # ボット応答を非同期で生成
    BotResponseJob.perform_later(
      conversation_id: @conversation.id,
      user_message_id: message.id
    )
  end

  def transmit_error(message)
    transmit(
      {
        type: 'error',
        message: 'メッセージの送信に失敗しました',
        errors: message.errors.full_messages
      }
    )
  end

  def update_message_read_status(message)
    message.add_metadata('read_by', current_user.id)
    message.add_metadata('read_at', Time.current)
  end

  def broadcast_message_read(message)
    ActionCable.server.broadcast(
      channel_name,
      {
        type: 'message_read',
        message_id: message.id,
        user_id: current_user.id,
        timestamp: Time.current
      }
    )
  end
end
