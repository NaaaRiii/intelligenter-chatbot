module Api
  module V1
    class ConversationsController < BaseController
      skip_before_action :authenticate_api_user!, only: [:index, :show, :create, :messages, :resume]
      before_action :set_or_create_session_id
      before_action :set_conversation, only: [:show, :messages, :resume]

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
        
        render json: {
          conversation: @conversation.as_json(
            include: {
              messages: { only: [:id, :content, :role, :created_at] }
            }
          )
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
        params.require(:conversation).permit(:session_id, :status, :guest_user_id, metadata: {})
      end
    end
  end
end