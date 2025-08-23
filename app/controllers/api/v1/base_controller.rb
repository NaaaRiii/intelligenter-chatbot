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
        # Accept explicit test user header first
        test_user_id = request.headers['X-Test-User-Id'] || request.headers['X-Test-User-ID']
        if test_user_id.present?
          @current_user = User.find_by(id: test_user_id)
          return head :unauthorized unless @current_user

          return true
        end

        # Fallback to Authorization: Bearer <token> even in test
        authorized = authenticate_with_http_token do |token, _options|
          @current_user = User.find_by(api_token: token)
        end
        return head :unauthorized unless authorized && @current_user

        true
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
