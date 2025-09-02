# frozen_string_literal: true

# チャットボットの応答生成サービス
class ChatBotService
  include ActiveModel::Model

  attr_accessor :conversation, :user_message, :context

  validates :conversation, presence: true
  validates :user_message, presence: true

  # 応答タイプの定義
  RESPONSE_TYPES = {
    greeting: 'greeting',
    question: 'question',
    complaint: 'complaint',
    feedback: 'feedback',
    general: 'general'
  }.freeze

  def initialize(conversation:, user_message:, context: {})
    @conversation = conversation
    @user_message = user_message
    @context = context
    @rag_service = RagService.new
    @context_injection_service = ContextInjectionService.new
    @claude_service = EnhancedClaudeApiService.new
  end

  # ボット応答を生成（RAG版を優先使用）
  def generate_response # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
    return nil unless valid?

    # RAG版を優先的に使用
    response = generate_response_with_rag
    return response if response

    # フォールバック: 従来版
    intent = recognize_intent
    response_content = build_response_with_category(intent)

    # 応答メッセージを作成
    bot_message = conversation.messages.build(
      content: response_content,
      role: 'assistant',
      metadata: {
        intent: intent[:type],
        confidence: intent[:confidence],
        template_used: intent[:template_id]
      }
    )

    if bot_message.save
      broadcast_response(bot_message)
      bot_message
    else
      errors.add(:base, 'ボット応答の保存に失敗しました')
      nil
    end
  rescue StandardError => e
    Rails.logger.error "Bot response generation failed: #{e.message}"
    errors.add(:base, 'システムエラーが発生しました')
    nil
  end

  # 非同期でボット応答を生成
  def generate_response_async?
    return false unless valid?

    BotResponseJob.perform_later(
      conversation_id: conversation.id,
      user_message_id: user_message.id
    )
    true
  end

  # RAGを活用した応答生成
  def generate_response_with_rag
    return nil unless valid?

    Rails.logger.info "[ChatBotService] Starting RAG-enhanced response generation"
    Rails.logger.info "[ChatBotService] User message: #{@user_message.content}"

    begin
      # 1. RAGパイプラインでコンテキスト取得
      Rails.logger.info "[ChatBotService] Step 1: Running RAG pipeline"
      rag_result = @rag_service.rag_pipeline(@user_message.content, conversation: @conversation)
      Rails.logger.info "[ChatBotService] RAG result: #{rag_result.inspect}"
    rescue StandardError => e
      Rails.logger.error "[ChatBotService] RAG pipeline failed: #{e.message}"
      rag_result = { context: {}, performance_metrics: {} }
    end
    
    begin
      # 2. FAQ、事例、製品情報を注入
      Rails.logger.info "[ChatBotService] Step 2: Injecting context"
      enriched_context = @context_injection_service.inject_context(@user_message.content, conversation: @conversation)
      Rails.logger.info "[ChatBotService] Enriched context: #{enriched_context.keys}"
    rescue StandardError => e
      Rails.logger.error "[ChatBotService] Context injection failed: #{e.message}"
      enriched_context = { faqs: [], case_studies: [], product_info: {} }
    end
    
    # 3. 統合コンテキストを構築
    combined_context = {
      rag_context: rag_result[:context],
      faqs: enriched_context[:faqs],
      case_studies: enriched_context[:case_studies],
      product_info: enriched_context[:product_info]
    }
    
    # 4. 会話履歴を準備
    conversation_history = prepare_conversation_history
    Rails.logger.info "[ChatBotService] Conversation history: #{conversation_history.size} messages"
    
    # 5. Claude APIに拡張コンテキストと共に送信
    Rails.logger.info "[ChatBotService] Step 5: Calling Claude API with context"
    response_content = @claude_service.generate_response_with_context(
      conversation_history,
      @user_message.content,
      combined_context
    )
    Rails.logger.info "[ChatBotService] Claude response: #{response_content&.truncate(100)}"
    
    # 応答が空の場合はフォールバック
    if response_content.blank?
      Rails.logger.warn "[ChatBotService] Claude returned empty response, using fallback"
      response_content = generate_emergency_fallback_response(@user_message.content, 'general')
    end
    
    # 6. 応答メッセージを作成・保存
    bot_message = save_bot_message(response_content, rag_result)
    
    if bot_message
      broadcast_response(bot_message)
      bot_message
    else
      errors.add(:base, 'ボット応答の保存に失敗しました')
      nil
    end
  rescue StandardError => e
    Rails.logger.error "[ChatBotService] RAG-enhanced response generation failed: #{e.message}"
    Rails.logger.error "[ChatBotService] Backtrace: #{e.backtrace.first(5).join("\n")}"
    # RAGなしでフォールバック
    generate_response
  end

  private

  # 意図を認識
  def recognize_intent
    analyzer = IntentRecognizer.new(message: user_message.content)
    intent_result = analyzer.recognize

    {
      type: intent_result[:type] || RESPONSE_TYPES[:general],
      confidence: intent_result[:confidence] || 0.5,
      keywords: intent_result[:keywords] || [],
      template_id: nil
    }
  end

  # カテゴリー別の応答を構築
  def build_response_with_category(intent)
    category = conversation.metadata&.dig('category') || 'general'
    
    # 拡張サービスで広く回答しつつ、会社情報を背景に活用
    conversation_history = prepare_conversation_history
    
    # NaturalConversationServiceを優先的に使用
    response_content = nil
    
    begin
      natural_service = NaturalConversationService.new
      context = { category: category }
      response_content = natural_service.generate_natural_response(
        @user_message.content,
        conversation_history,
        context
      )
      
      # 空の応答をチェック
      if response_content.nil? || response_content.strip.empty?
        Rails.logger.warn "Natural conversation returned empty response, using enhanced service"
        raise StandardError.new("Empty response from natural service")
      end
    rescue StandardError => e
      Rails.logger.warn "Natural conversation failed, using enhanced service: #{e.message}"
      # フォールバック: EnhancedClaudeApiServiceを使用
      begin
        response_content = @claude_service.generate_enhanced_response(
          conversation_history,
          @user_message.content,
          { category: category }
        )
      rescue StandardError => fallback_error
        Rails.logger.error "Enhanced service also failed: #{fallback_error.message}"
        # 最終フォールバック
        response_content = generate_emergency_fallback_response(@user_message.content, category)
      end
    end
    
    # 最終チェック
    if response_content.nil? || response_content.strip.empty?
      response_content = generate_emergency_fallback_response(@user_message.content, category)
    end

    # 大きく話が逸れている場合は、やんわり元カテゴリへ誘導文を付与
    begin
      deviation = TopicDeviationService.new.detect_deviation(message: @user_message.content, conversation: @conversation)
      if deviation[:deviated] && deviation[:topic_relevance].to_f < TopicDeviationService::TOPIC_RELEVANCE_THRESHOLD
        suggestion = TopicDeviationService.new.suggest_redirect(deviation)
        transition = suggestion[:transition_phrase]
        redirect_msg = suggestion[:redirect_message]
        response_content = [response_content, "\n\n#{transition}#{redirect_msg}。"].compact.join
      end
    rescue StandardError => e
      Rails.logger.warn "Topic deviation handling skipped: #{e.message}"
    end

    response_content || build_response_fallback(intent)
  end

  # 応答を構築（フォールバック）
  def build_response_fallback(intent)
    template_manager = ResponseTemplates.new(
      intent_type: intent[:type],
      context: build_context(intent)
    )

    response = template_manager.response
    intent[:template_id] = template_manager.template_id

    response
  end

  # コンテキストを構築
  def build_context(intent)
    {
      user_name: context[:user_name] || 'お客様',
      conversation_id: conversation.id,
      message_count: conversation.messages.count,
      intent_keywords: intent[:keywords],
      previous_messages: recent_messages,
      time_of_day: greeting_time
    }
  end

  # 最近のメッセージを取得
  def recent_messages
    conversation.messages
                .latest_n(5)
                .pluck(:content, :role)
                .map { |content, role| { content: content, role: role } }
  end

  # 時間帯に応じた挨拶
  def greeting_time
    hour = Time.current.hour
    case hour
    when 5..10 then 'morning'
    when 11..17 then 'afternoon'
    when 18..22 then 'evening'
    else 'night'
    end
  end

  # WebSocketで応答を配信
  def broadcast_response(bot_message)
    ConversationChannel.broadcast_to(
      conversation,
      {
        type: 'bot_response',
        message: {
          id: bot_message.id,
          content: bot_message.content,
          role: bot_message.role,
          created_at: bot_message.created_at,
          metadata: bot_message.metadata
        }
      }
    )
  end

  # 緊急フォールバック応答を生成
  def generate_emergency_fallback_response(user_message, category)
    if user_message.include?('連携') && user_message.include?('セキュリティ')
      <<~RESPONSE
        ECモール連携とセキュリティについて、順番にお答えいたします。

        【ECモール連携について】
        楽天市場、Amazon、Yahoo!ショッピングの主要3モールとの連携に対応しています。
        - 商品情報の一括管理と同期
        - 在庫の自動更新機能
        - 注文データの統合管理
        - 各モールのAPIを活用した効率的な運用

        【セキュリティ対策について】
        お客様の大切な情報を守るため、以下の対策を実施しています：
        - SSL/TLS暗号化通信（256bit）
        - WAF（Webアプリケーションファイアウォール）導入
        - ISO27001準拠のセキュリティ管理体制
        - 定期的な脆弱性診断とペネトレーションテスト
        - 個人情報保護法およびGDPRに準拠した運用

        より詳しい仕様や導入事例について説明が必要でしたら、お聞かせください。
      RESPONSE
    elsif user_message.include?('連携')
      <<~RESPONSE
        ECモール連携についてご案内いたします。

        主要ECモール（楽天市場、Amazon、Yahoo!ショッピング）との連携に対応しており、
        商品管理、在庫同期、注文処理を一元化できます。

        APIを活用した自動連携により、運用工数を大幅に削減可能です。
        具体的な連携要件がございましたら、お聞かせください。
      RESPONSE
    elsif user_message.include?('セキュリティ')
      <<~RESPONSE
        セキュリティ対策についてご案内いたします。

        SSL/TLS暗号化、WAF導入、ISO27001準拠の体制で
        お客様の情報を安全に保護します。

        定期的な脆弱性診断も実施しており、
        最新のセキュリティ脅威にも対応しています。

        詳細なセキュリティ要件がございましたら、お聞かせください。
      RESPONSE
    else
      <<~RESPONSE
        ご質問ありがとうございます。

        #{category == 'tech' ? '技術的な観点から' : 'お客様のニーズに合わせて'}最適なソリューションをご提供いたします。

        より具体的なご要望をお聞かせいただければ、
        詳細なご提案をさせていただきます。

        どのような課題やご要望をお持ちでしょうか？
      RESPONSE
    end
  end

  # 会話履歴を準備
  def prepare_conversation_history
    conversation.messages
                .order(:created_at)
                .limit(10)
                .map { |msg| { role: msg.role, content: msg.content } }
  end

  # ボットメッセージを保存
  def save_bot_message(response_content, rag_result = nil)
    metadata = {
      rag_used: rag_result.present?,
      sources_count: rag_result&.dig(:context, :retrieved_messages)&.size || 0,
      confidence_score: rag_result&.dig(:response, :confidence_score),
      performance_metrics: rag_result&.dig(:performance_metrics)
    }

    conversation.messages.create(
      content: response_content,
      role: 'assistant',
      metadata: metadata
    )
  end
end
