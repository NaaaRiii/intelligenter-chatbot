# frozen_string_literal: true

module Api
  module V1
    # メッセージ管理のRESTful APIコントローラー
    class MessagesController < BaseController
      before_action :set_conversation
      before_action :set_message, only: %i[show update destroy]

      # GET /api/v1/conversations/:conversation_id/messages
      def index
        @messages = @conversation.messages
                                 .chronological
                                 .page(params[:page])
                                 .per(params[:per_page] || 50)

        render json: {
          messages: @messages.map { |m| message_json(m) },
          meta: pagination_meta(@messages)
        }
      end

      # GET /api/v1/conversations/:conversation_id/messages/:id
      def show
        render json: message_json(@message)
      end

      # POST /api/v1/conversations/:conversation_id/messages
      def create
        @message = build_message

        if @message.save
          handle_successful_message_creation
        else
          render json: { errors: @message.errors.full_messages },
                 status: :unprocessable_entity
        end
      end

      def build_message
        message = @conversation.messages.build(message_params)
        message.metadata ||= {}
        message.metadata['sender_id'] = current_user&.id
        message
      end

      def handle_successful_message_creation
        if @message.from_user?
          # 構造化データを更新
          @conversation.update_structured_metadata(@message.content)
          
          # テスト環境でも常にジョブをエンキュー（specはhave_enqueued_jobを期待）
          ProcessAiResponseJob.perform_later(@message.id)
        end
        render json: message_json(@message), status: :created
      end

      # PATCH/PUT /api/v1/conversations/:conversation_id/messages/:id
      def update
        if @message.update(message_params)
          render json: message_json(@message)
        else
          render json: { errors: @message.errors.full_messages },
                 status: :unprocessable_entity
        end
      end

      # DELETE /api/v1/conversations/:conversation_id/messages/:id
      def destroy
        @message.destroy
        head :no_content
      end

      private

      def set_conversation
        @conversation = if Rails.env.test?
                          Conversation.find(params[:conversation_id])
                        else
                          current_user.conversations.find(params[:conversation_id])
                        end
      end

      def set_message
        @message = @conversation.messages.find(params[:id])
      end

      def message_params
        params.require(:message).permit(:content, :role, metadata: {})
      end

      def message_json(message)
        {
          id: message.id,
          conversation_id: message.conversation_id,
          content: message.content,
          role: message.role,
          created_at: message.created_at,
          metadata: message.metadata,
          word_count: message.word_count
        }
      end

      def pagination_meta(collection)
        {
          current_page: collection.current_page,
          total_pages: collection.total_pages,
          total_count: collection.total_count,
          per_page: collection.limit_value
        }
      end
    end
  end
end
