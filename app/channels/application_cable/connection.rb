module ApplicationCable
  class Connection < ActionCable::Connection::Base
    identified_by :session_id

    def connect
      self.session_id = find_or_create_session_id
      logger.add_tags 'ActionCable', session_id
    end

    private

    def find_or_create_session_id
      # 開発環境用の簡易セッションID
      # 本番環境では適切な認証を実装する必要があります
      cookies[:session_id] ||= SecureRandom.uuid
    end
  end
end
