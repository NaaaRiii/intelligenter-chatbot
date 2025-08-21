module ApplicationCable
  class Connection < ActionCable::Connection::Base
    identified_by :current_user

    def connect
      self.current_user = find_verified_user
      logger.add_tags 'ActionCable', current_user.email
    end

    private

    def find_verified_user
      # セッションまたはトークンベースの認証
      if (user = find_user_from_session)
        user
      else
        reject_unauthorized_connection
      end
    end

    def find_user_from_session
      # セッションからユーザーを取得
      if session_user_id = cookies.encrypted[:user_id]
        User.find_by(id: session_user_id)
      end
    end
  end
end
