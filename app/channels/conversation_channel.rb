class ConversationChannel < ApplicationCable::Channel
  def subscribed
    @conversation = find_or_create_conversation
    stream_for @conversation
  end

  def unsubscribed
    # Any cleanup needed when channel is unsubscribed
  end

  def send_message(data)
    Rails.logger.info "="*80
    Rails.logger.info "[FLOW START] ActionCable - ConversationChannel#send_message"
    Rails.logger.info "Conversation ID: #{@conversation.id}"
    Rails.logger.info "Received data: #{data.inspect}"
    Rails.logger.info "="*80
    
    # メッセージを保存してブロードキャスト
    message = @conversation.messages.create!(
      content: data['content'],
      role: data['role'] || 'user',
      metadata: data['metadata'] || {}
    )
    
    Rails.logger.info "[STEP 1] Message created - ID: #{message.id}, Content: #{message.content}"

    # すべての購読者にメッセージをブロードキャスト
    ConversationChannel.broadcast_to(
      @conversation,
      {
        message: message.as_json(
          only: [:id, :content, :role, :created_at, :metadata]
        )
      }
    )
    
    Rails.logger.info "[STEP 2] Message broadcasted to subscribers"

    # 初回の裏準備: 最初のユーザーメッセージでNeedPreviewJobをenqueue（既存がなければ）
    if message.user? && @conversation.messages.where(role: 'user').count == 1
      NeedPreviewJob.perform_later(@conversation.id)
      Rails.logger.info "[STEP 3] NeedPreviewJob enqueued for conversation ##{@conversation.id}"
    end

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
        
        Rails.logger.info "[STEP 3] Slack notification queued for #{category} inquiry: #{@conversation.id}"
      end
    end

    # アシスタントの返信が必要な場合は非同期ジョブをキュー
    if message.user?
      Rails.logger.info "[STEP 4] User message detected, queueing BotResponseJob"
      Rails.logger.info "  - Conversation ID: #{@conversation.id}"
      Rails.logger.info "  - User Message ID: #{message.id}"
      Rails.logger.info "  - Message Content: #{message.content}"
      
      BotResponseJob.perform_later(
        conversation_id: @conversation.id,
        user_message_id: message.id
      )
      
      Rails.logger.info "[STEP 5] BotResponseJob queued successfully"

      # 2-3往復に到達したら本分析（直近5-8件）をSidekiqワーカーで再推定
      flags = Rails.configuration.x.needs_preview
      user_turns = @conversation.messages.where(role: 'user').count
      if flags.enabled && user_turns >= flags.turn_threshold_min && user_turns <= flags.turn_threshold_max
        ConversationAnalysisWorker.perform_async(@conversation.id, { 'use_storage' => false })
        Rails.logger.info "[STEP 6] ConversationAnalysisWorker enqueued for needs_preview update (turns=#{user_turns})"
      end
    else
      Rails.logger.info "[STEP 4] Non-user message, skipping bot response"
    end
    
    Rails.logger.info "[FLOW END] ActionCable - ConversationChannel#send_message"
    Rails.logger.info "="*80
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