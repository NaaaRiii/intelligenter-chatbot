module Api
  module V1
    class ConversationsController < BaseController
      skip_before_action :authenticate_api_user!, only: [:index, :show, :create, :update, :messages, :resume]
      before_action :set_or_create_session_id
      before_action :set_conversation, only: [:show, :update, :messages, :resume]

      # GET /api/v1/conversations
      def index
        # ユーザーIDがある場合は、そのユーザーの全会話を取得
        # なければセッションIDで取得（後方互換性）
        if @user_id.present?
          @conversations = Conversation.includes(:messages)
                                     .where(guest_user_id: @user_id)
                                     .order(updated_at: :desc)
                                     .page(params[:page])
                                     .per(params[:per_page] || 10)
        else
          @conversations = Conversation.includes(:messages)
                                     .where(session_id: @session_id)
                                     .order(updated_at: :desc)
                                     .page(params[:page])
                                     .per(params[:per_page] || 10)
        end
        
        render json: {
          conversations: @conversations.as_json(
            include: {
              messages: { only: [:id, :content, :role, :created_at, :metadata] }
            },
            methods: [:metadata]
          ),
          meta: {
            current_page: @conversations.current_page,
            total_pages: @conversations.total_pages,
            total_count: @conversations.total_count
          }
        }
      end

      # GET /api/v1/conversations/:id
      def show
        render json: {
          conversation: @conversation.as_json(
            include: {
              messages: { only: [:id, :content, :role, :created_at, :metadata] }
            },
            methods: [:metadata]
          )
        }
      end

      # POST /api/v1/conversations
      def create
        @conversation = Conversation.new(conversation_params)
        @conversation.guest_user_id = @user_id if @user_id.present?
        @conversation.save!
        
        # 初回メッセージがある場合は処理
        if params[:initial_message].present?
          initial_message = @conversation.messages.create!(
            content: params[:initial_message],
            role: 'user',
            metadata: {
              category: params[:category],
              customer_type: params[:customer_type]
            }
          )
          
          # AI応答をバックグラウンドで生成
          ProcessAiResponseJob.perform_later(initial_message.id)
          Rails.logger.info "Initial message created and AI response job queued for conversation #{@conversation.id}"
        end
        
        # マーケティングカテゴリーの新規顧客の場合、Slack通知を送信
        # customerTypeとcustomer_typeの両方をチェック
        if @conversation.metadata&.dig('category') == 'marketing' && 
           (@conversation.metadata&.dig('customerType') == 'new' || 
            @conversation.metadata&.dig('customer_type') == 'new')
          send_slack_notification_for_marketing
        end
        
        render json: {
          conversation: @conversation.as_json(
            include: {
              messages: { only: [:id, :content, :role, :created_at] }
            }
          ),
          id: @conversation.id  # 明示的にIDを追加
        }, status: :created
      end

      # GET /api/v1/conversations/:id/messages
      def messages
        @messages = @conversation.messages
                                .chronological
                                .page(params[:page])
                                .per(params[:per_page] || 50)
        
        render json: {
          messages: @messages.as_json(
            only: [:id, :content, :role, :created_at, :metadata]
          ),
          meta: {
            current_page: @messages.current_page,
            total_pages: @messages.total_pages,
            total_count: @messages.total_count
          }
        }
      end

      # PATCH/PUT /api/v1/conversations/:id
      def update
        # 既存のmetadataとマージ
        if params[:conversation][:metadata].present?
          existing_metadata = @conversation.metadata || {}
          # パラメータを明示的にハッシュに変換
          new_metadata_params = params[:conversation][:metadata].to_unsafe_h
          new_metadata = existing_metadata.merge(new_metadata_params)
          Rails.logger.info "Updating conversation #{@conversation.id} metadata: #{existing_metadata} -> #{new_metadata}"
          @conversation.metadata = new_metadata
          
          # マーケティングカテゴリーが選択された場合にSlack通知を送信
          # customerTypeとcustomer_typeの両方をチェック
          if new_metadata['category'] == 'marketing' && 
             (new_metadata['customerType'] == 'new' || new_metadata['customer_type'] == 'new') &&
             existing_metadata['category'] != 'marketing'
            send_slack_notification_for_marketing
          end
        end
        
        # その他のパラメータも更新（metadataを除く）
        permitted_params = conversation_params
        if permitted_params.except(:metadata).present?
          @conversation.assign_attributes(permitted_params.except(:metadata))
        end
        
        if @conversation.save
          Rails.logger.info "Conversation #{@conversation.id} saved with metadata: #{@conversation.metadata}"
          render json: {
            conversation: @conversation.as_json(
              include: {
                messages: { only: [:id, :content, :role, :created_at] }
              }
            )
          }
        else
          render json: { errors: @conversation.errors.full_messages }, status: :unprocessable_entity
        end
      end

      # POST /api/v1/conversations/:id/resume
      def resume
        @conversation.update!(status: 'active', updated_at: Time.current)
        render json: {
          conversation: @conversation.as_json(
            include: {
              messages: { only: [:id, :content, :role, :created_at] }
            }
          )
        }
      end

      private

      def set_or_create_session_id
        @session_id = request.headers['X-Session-Id'] || request.headers['Cookie']&.match(/session_id=([^;]+)/)&.[](1)
        @user_id = request.headers['X-User-Id']
        
        if @session_id.blank?
          @session_id = SecureRandom.uuid
          response.set_header('Set-Cookie', "session_id=#{@session_id}; HttpOnly; SameSite=Lax; Path=/")
        end
      end

      def set_conversation
        # 数値IDの場合のみ検索、文字列IDの場合は404を返す
        if params[:id].to_s.match?(/^\d+$/)
          # guest_user_idでフィルタリング（ユーザーの会話のみアクセス可能）
          if @user_id.present?
            @conversation = Conversation.where(guest_user_id: @user_id).find(params[:id])
          else
            @conversation = Conversation.find(params[:id])
          end
        else
          # "chat-xxx"のような文字列IDは存在しないものとして扱う
          render json: { error: 'Conversation not found' }, status: :not_found
        end
      rescue ActiveRecord::RecordNotFound
        render json: { error: 'Conversation not found' }, status: :not_found
      end

      def conversation_params
        # metadataのすべてのキーを許可
        if params[:conversation][:metadata].present?
          metadata_keys = params[:conversation][:metadata].keys
          params.require(:conversation).permit(:session_id, :status, :guest_user_id, metadata: metadata_keys)
        else
          params.require(:conversation).permit(:session_id, :status, :guest_user_id)
        end
      end

      def send_slack_notification_for_marketing
        # 最初のメッセージを取得（お客様の問い合わせ内容）
        first_message = @conversation.messages.where(role: 'user').chronological.first
        return unless first_message

        customer_name = @conversation.metadata['customer_name'] || 
                       @conversation.guest_user_id || 
                       "ゲストユーザー"

        # 非同期でSlack通知を送信
        SlackNotificationJob.perform_later(
          category: 'marketing',
          customer_name: customer_name,
          message: first_message.content,
          conversation_id: @conversation.id
        )
        
        Rails.logger.info "Slack notification queued for marketing inquiry: #{@conversation.id}"
      rescue => e
        Rails.logger.error "Failed to queue Slack notification: #{e.message}"
      end
    end
  end
end