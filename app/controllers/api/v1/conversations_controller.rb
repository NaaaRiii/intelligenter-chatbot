# frozen_string_literal: true

module Api
  module V1
    # 会話管理のRESTful APIコントローラー
    class ConversationsController < BaseController
      before_action :set_conversation, only: %i[show update destroy]

      # GET /api/v1/conversations
      def index
        @conversations = current_user.conversations
                                     .includes(:messages, :analyses)
                                     .page(params[:page])
                                     .per(params[:per_page] || 20)

        render json: {
          conversations: @conversations.map { |c| conversation_json(c) },
          meta: pagination_meta(@conversations)
        }
      end

      # GET /api/v1/conversations/:id
      def show
        render json: conversation_json(@conversation, include_messages: true)
      end

      # POST /api/v1/conversations
      def create
        @conversation = current_user.conversations.build(conversation_params)

        if @conversation.save
          render json: conversation_json(@conversation), status: :created
        else
          render json: { errors: @conversation.errors.full_messages },
                 status: :unprocessable_entity
        end
      end

      # PATCH/PUT /api/v1/conversations/:id
      def update
        if @conversation.update(conversation_params)
          render json: conversation_json(@conversation)
        else
          render json: { errors: @conversation.errors.full_messages },
                 status: :unprocessable_entity
        end
      end

      # DELETE /api/v1/conversations/:id
      def destroy
        @conversation.destroy
        head :no_content
      end

      private

      def set_conversation
        @conversation = current_user.conversations.find(params[:id])
      end

      def conversation_params
        params.require(:conversation).permit(:session_id, metadata: {})
      end

      def conversation_json(conversation, include_messages: false)
        json = build_conversation_json(conversation)
        json[:messages] = build_messages_json(conversation) if include_messages
        json
      end

      def build_conversation_json(conversation)
        {
          id: conversation.id,
          session_id: conversation.session_id,
          is_active: conversation.active?,
          ended_at: conversation.ended_at,
          created_at: conversation.created_at,
          updated_at: conversation.updated_at,
          metadata: conversation.metadata,
          message_count: conversation.messages.count,
          latest_analysis: conversation.analyses.last&.slice(
            :analysis_type, :sentiment, :priority_level
          )
        }
      end

      def build_messages_json(conversation)
        conversation.messages.chronological.map do |msg|
          {
            id: msg.id,
            content: msg.content,
            role: msg.role,
            created_at: msg.created_at,
            metadata: msg.metadata
          }
        end
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
