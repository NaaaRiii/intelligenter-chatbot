# frozen_string_literal: true

# メッセージのキャッシュ機能を提供するConcern
module CacheableMessage
  extend ActiveSupport::Concern

  included do
    # キャッシュキーのプレフィックス
    CACHE_KEY_PREFIX = 'messages'
    CACHE_EXPIRY = 1.hour

    # キャッシュ更新コールバック
    after_commit :expire_cache_on_create, on: :create
    after_commit :expire_cache_on_update, on: :update
    after_commit :expire_cache_on_destroy, on: :destroy
  end

  class_methods do
    # 会話のメッセージをキャッシュから取得
    def cached_for_conversation(conversation_id, limit = 50)
      cache_key = build_conversation_cache_key(conversation_id, limit)
      
      Rails.cache.fetch(cache_key, expires_in: CACHE_EXPIRY) do
        for_conversation(conversation_id)
          .chronological
          .latest_n(limit)
          .includes(:conversation)
          .to_a
      end
    end

    # 最近のメッセージをキャッシュから取得
    def cached_recent(limit = 20)
      cache_key = build_recent_cache_key(limit)
      
      Rails.cache.fetch(cache_key, expires_in: CACHE_EXPIRY) do
        recent
          .limit(limit)
          .includes(:conversation)
          .to_a
      end
    end

    # ユーザーメッセージをキャッシュから取得
    def cached_user_messages(conversation_id, limit = 30)
      cache_key = build_role_cache_key(conversation_id, 'user', limit)
      
      Rails.cache.fetch(cache_key, expires_in: CACHE_EXPIRY) do
        for_conversation(conversation_id)
          .user_messages
          .chronological
          .limit(limit)
          .to_a
      end
    end

    # キャッシュキーの構築
    def build_conversation_cache_key(conversation_id, limit)
      "#{CACHE_KEY_PREFIX}/conversation/#{conversation_id}/limit/#{limit}"
    end

    def build_recent_cache_key(limit)
      "#{CACHE_KEY_PREFIX}/recent/#{limit}"
    end

    def build_role_cache_key(conversation_id, role, limit)
      "#{CACHE_KEY_PREFIX}/conversation/#{conversation_id}/role/#{role}/limit/#{limit}"
    end

    # 会話に関連するすべてのキャッシュをクリア
    def expire_conversation_cache(conversation_id)
      Rails.cache.delete_matched("#{CACHE_KEY_PREFIX}/conversation/#{conversation_id}/*")
      Rails.cache.delete_matched("#{CACHE_KEY_PREFIX}/recent/*")
    end
  end

  private

  # キャッシュ無効化メソッド
  def expire_cache_on_create
    expire_related_caches
  end

  def expire_cache_on_update
    expire_related_caches
  end

  def expire_cache_on_destroy
    expire_related_caches
  end

  def expire_related_caches
    # 会話関連のキャッシュをクリア
    self.class.expire_conversation_cache(conversation_id)
    
    # Redisを使用している場合の最適化
    if Rails.cache.is_a?(ActiveSupport::Cache::RedisCacheStore)
      expire_redis_caches
    end
  end

  def expire_redis_caches
    redis = Rails.cache.redis
    pattern = "#{CACHE_KEY_PREFIX}/conversation/#{conversation_id}/*"
    
    # LuaスクリプトでRedisキーを効率的に削除
    lua_script = <<~LUA
      local keys = redis.call('keys', ARGV[1])
      for i=1,#keys,5000 do
        redis.call('del', unpack(keys, i, math.min(i+4999, #keys)))
      end
      return #keys
    LUA
    
    redis.eval(lua_script, [], [pattern])
  rescue StandardError => e
    Rails.logger.error "Failed to expire Redis cache: #{e.message}"
  end
end