class ConversationChannel < ApplicationCable::Channel
  def subscribed
    @conversation = find_or_create_conversation
    stream_for @conversation
  end

  def unsubscribed
    # Any cleanup needed when channel is unsubscribed
  end

  def send_message(data)
    # メッセージを保存してブロードキャスト
    message = @conversation.messages.create!(
      content: data['content'],
      role: data['role'] || 'user',
      metadata: data['metadata'] || {}
    )

    # すべての購読者にメッセージをブロードキャスト
    ConversationChannel.broadcast_to(
      @conversation,
      {
        message: message.as_json(
          only: [:id, :content, :role, :created_at, :metadata]
        )
      }
    )

    # アシスタントの返信が必要な場合は非同期ジョブをキュー
    if message.user?
      GenerateAssistantResponseJob.perform_later(@conversation.id)
    end
  end

  private

  def find_or_create_conversation
    # セッションIDまたは渡されたIDで会話を取得/作成
    conversation_id = params[:conversation_id]
    
    if conversation_id.present?
      Conversation.find_or_create_by(id: conversation_id) do |conv|
        conv.session_id = session_id
      end
    else
      Conversation.find_or_create_by(session_id: session_id) do |conv|
        conv.status = 'active'
      end
    end
  end
end