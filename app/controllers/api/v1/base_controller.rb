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
        return authenticate_test_user if Rails.env.test?

        authenticate_or_request_with_http_token do |token|
          @current_user = User.find_by(api_token: token)
        end
      end

      def authenticate_test_user
        # 明示ヘッダーを最優先で使用
        test_user_id = request.headers['X-Test-User-Id'] || request.headers['X-Test-User-ID']
        if test_user_id.present?
          @current_user = User.find_by(id: test_user_id)
          return true if @current_user
          render json: { error: 'Unauthorized' }, status: :unauthorized and return
        end

        # Bearerトークンも許可
        authenticate_with_http_token do |token, _options|
          @current_user = User.find_by(api_token: token)
          return true if @current_user
        end

        # それ以外は明示的に401
        render json: { error: 'Unauthorized' }, status: :unauthorized and return
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
