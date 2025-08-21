class ChatChannel < ApplicationCable::Channel
  def subscribed
    # 会話IDを元にストリームを購読
    if params[:conversation_id].present?
      @conversation = Conversation.find_by(id: params[:conversation_id])
      
      if @conversation && authorized?
        stream_from channel_name
        
        # 接続通知
        ActionCable.server.broadcast(
          channel_name,
          {
            type: 'user_connected',
            user: current_user.slice(:id, :name, :email),
            timestamp: Time.current
          }
        )
      else
        reject
      end
    else
      reject
    end
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

    message = @conversation.messages.build(
      content: data['content'],
      role: 'user',
      metadata: {
        sender_id: current_user.id,
        sent_at: Time.current
      }
    )

    if message.save
      # メッセージをブロードキャスト
      broadcast_message(message)
      
      # AI応答をトリガー（非同期）
      ProcessAiResponseJob.perform_later(message.id) if should_process_ai_response?
    else
      transmit(
        {
          type: 'error',
          message: 'メッセージの送信に失敗しました',
          errors: message.errors.full_messages
        }
      )
    end
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

    if data['message_id'].present?
      message = @conversation.messages.find_by(id: data['message_id'])
      
      if message
        message.add_metadata('read_by', current_user.id)
        message.add_metadata('read_at', Time.current)
        
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
end