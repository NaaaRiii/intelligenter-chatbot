module Api
  module V1
    class ConversationsController < BaseController
      before_action :set_conversation, only: [:show, :messages]

      # GET /api/v1/conversations
      def index
        @conversations = Conversation.includes(:messages)
                                   .order(updated_at: :desc)
                                   .page(params[:page])
        
        render json: {
          conversations: @conversations.as_json(
            include: {
              messages: { only: [:id, :content, :role, :created_at] }
            }
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
            }
          )
        }
      end

      # POST /api/v1/conversations
      def create
        @conversation = Conversation.create!(conversation_params)
        
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

      private

      def set_conversation
        @conversation = Conversation.find(params[:id])
      end

      def conversation_params
        params.require(:conversation).permit(:session_id, :status, metadata: {})
      end
    end
  end
end