# frozen_string_literal: true

module Api
  module V1
    # API V1の基底コントローラー
    class BaseController < ActionController::API
      include ActionController::HttpAuthentication::Token::ControllerMethods

      before_action :authenticate_api_user!

      rescue_from ActiveRecord::RecordNotFound, with: :not_found
      rescue_from ActiveRecord::RecordInvalid, with: :unprocessable_entity

      private

      def authenticate_api_user!
        authenticate_or_request_with_http_token do |token|
          @current_user = User.find_by(api_token: token)
        end
      end

      attr_reader :current_user

      def not_found(exception)
        render json: { error: exception.message }, status: :not_found
      end

      def unprocessable_entity(exception)
        render json: {
          error: exception.message,
          errors: exception.record.errors.full_messages
        }, status: :unprocessable_entity
      end
    end
  end
end
