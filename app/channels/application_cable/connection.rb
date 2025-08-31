module ApplicationCable
  class Connection < ActionCable::Connection::Base
    identified_by :uuid

    def connect
      self.uuid = find_or_create_session_id
      logger.add_tags 'ActionCable', uuid
    end

    private

    def find_or_create_session_id
      # 各接続ごとに新しいセッションIDを生成（タブごとに異なる）
      # これにより各タブが独立した会話を持つ
      SecureRandom.uuid
    end
  end
end
