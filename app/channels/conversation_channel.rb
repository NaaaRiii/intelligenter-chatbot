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

    # 最初のユーザーメッセージで新規顧客の場合、Slack通知を送信
    if message.user? && 
       @conversation.messages.where(role: 'user').count == 1 &&
       @conversation.metadata&.dig('customerType') == 'new'
      
      category = @conversation.metadata&.dig('category')
      
      if category.present?
        customer_name = @conversation.metadata['contactName'] || 
                       @conversation.metadata['customer_name'] ||
                       @conversation.guest_user_id || 
                       "ゲストユーザー"
        
        SlackNotificationJob.perform_later(
          category: category,
          customer_name: customer_name,
          message: message.content,
          conversation_id: @conversation.id
        )
        
        Rails.logger.info "Slack notification queued for #{category} inquiry: #{@conversation.id}"
      end
    end

    # アシスタントの返信が必要な場合は非同期ジョブをキュー
    if message.user?
      GenerateAssistantResponseJob.perform_later(@conversation.id)
    end
  end

  private

  def find_or_create_conversation
    # セッションIDまたは渡されたIDで会話を取得/作成
    conversation_id = params[:conversation_id]
    
    # "chat"や"chat-xxx"のような文字列IDの場合は新規作成
    if conversation_id.present? && conversation_id.to_s.match?(/^\d+$/)
      # 数値IDの場合のみ既存の会話を検索
      conversation = Conversation.find_by(id: conversation_id)
      if conversation
        conversation
      else
        Conversation.create!(session_id: connection.uuid, status: 'active')
      end
    else
      # 文字列IDまたはIDなしの場合は既存の会話を検索または新規作成
      # connection.uuidはActionCableのセッションID（タブごと）
      session_id_value = connection.uuid
      
      # ユーザーIDをCookieから取得
      user_id_value = cookies[:user_id]
      
      # 既存の会話を検索（同じタブセッションで）
      conversation = Conversation.find_by(session_id: session_id_value)
      if conversation
        conversation
      else
        # 新規作成時にユーザーIDも保存
        Conversation.create!(
          session_id: session_id_value, 
          guest_user_id: user_id_value,
          status: 'active'
        )
      end
    end
  end
end