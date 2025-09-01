# frozen_string_literal: true

# 自動会話機能を統合した拡張版ChatBotService
class EnhancedChatBotService < ChatBotService
  def initialize(conversation: nil, user_message: nil, context: {})
    super(conversation: conversation, user_message: user_message, context: context) if conversation && user_message
    @auto_conversation_service = AutoConversationService.new
  end

  # 自動応答を生成（3-5往復の情報収集対応）
  def generate_auto_response(conversation, user_message, auto_conversation: false)
    return generate_fallback_response unless auto_conversation

    begin
      # メタデータの初期化
      conversation.metadata ||= {}
      ai_count = conversation.metadata['ai_interaction_count'] || 0
      
      # 初回メッセージの場合
      if ai_count == 0
        result = @auto_conversation_service.process_initial_message(conversation, user_message)
        
        # メタデータを更新
        conversation.metadata.merge!({
          'category' => result[:category],
          'collected_info' => result[:collected_info],
          'ai_interaction_count' => 1,
          'auto_conversation' => true
        })
        conversation.save!
        
        return result[:next_question] || generate_summary(result[:collected_info], result[:category])
      end
      
      # 2回目以降のメッセージ
      category = conversation.metadata['category'] || 'general'
      collected_info = conversation.metadata['collected_info'] || {}
      
      # 新しい情報を抽出
      new_info = @auto_conversation_service.extract_information(user_message, category)
      # シンボルキーを文字列キーに変換
      new_info.each do |key, value|
        collected_info[key.to_s] = value
      end
      
      # AI応答回数をインクリメント
      conversation.metadata['ai_interaction_count'] = ai_count + 1
      conversation.metadata['collected_info'] = collected_info
      
      # 継続判定
      if should_continue_auto_conversation?(conversation)
        # 次の質問を生成
        next_question = @auto_conversation_service.generate_next_question(collected_info, category)
        
        if next_question
          conversation.save!
          return next_question
        end
      end
      
      # 情報収集完了またはエスカレーション
      conversation.metadata['escalation_required'] = true
      conversation.save!
      
      generate_summary(collected_info, category)
      
    rescue StandardError => e
      Rails.logger.error "Auto conversation error: #{e.message}"
      generate_fallback_response
    end
  end

  # 自動会話を継続すべきか判定
  def should_continue_auto_conversation?(conversation)
    return false unless conversation.respond_to?(:bot_enabled) ? conversation.bot_enabled : true
    
    metadata = conversation.metadata || {}
    
    # 明示的にauto_conversationがfalseの場合
    return false if metadata['auto_conversation'] == false
    
    # エスカレーションフラグが立っている場合
    return false if metadata['escalation_required'] == true
    
    # AutoConversationServiceの判定を使用
    @auto_conversation_service.should_continue_conversation?(metadata)
  end

  private

  def generate_summary(collected_info, category)
    @auto_conversation_service.generate_summary(collected_info, category)
  end

  def generate_fallback_response
    '申し訳ございません。現在システムに接続できません。' \
    'サポートチームまでお問い合わせください。'
  end
end