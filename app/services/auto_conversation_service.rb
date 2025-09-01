# frozen_string_literal: true

# 自動会話機能を管理するサービス
# 初回メッセージから必要情報を特定し、3-5往復で情報収集を完了させる
class AutoConversationService
  # カテゴリ別の必要情報定義
  REQUIRED_INFO = {
    'marketing' => {
      essential: %w[business_type budget_range current_tools],
      optional: %w[target_metrics challenges timeline],
      priority_order: %w[business_type budget_range current_tools target_metrics challenges timeline]
    },
    'tech' => {
      essential: %w[system_type error_details occurrence_time],
      optional: %w[affected_users attempted_solutions],
      priority_order: %w[system_type error_details occurrence_time affected_users attempted_solutions]
    },
    'general' => {
      essential: %w[inquiry_type company_size],
      optional: %w[timeline budget_consideration],
      priority_order: %w[inquiry_type company_size timeline budget_consideration]
    }
  }.freeze

  # 質問テンプレート
  QUESTION_TEMPLATES = {
    'business_type' => 'どのような業界・事業を運営されていますか？具体的な商品やサービスも教えていただけますでしょうか。',
    'budget_range' => '月額でどの程度のご予算をお考えでしょうか？現在のマーケティング費用でも構いません。',
    'current_tools' => '現在お使いのツールやシステムがあれば教えてください。（例：Google Analytics, Shopify等）',
    'target_metrics' => '改善したい指標や達成したい目標はありますか？（例：CVR向上、売上拡大等）',
    'challenges' => '現在お困りの課題や改善したい点を具体的に教えていただけますか？',
    'timeline' => 'いつまでに改善を実現したいとお考えですか？',
    'system_type' => 'どのようなシステムで問題が発生していますか？',
    'error_details' => 'エラーの詳細や表示されているメッセージを教えてください。',
    'occurrence_time' => 'いつから、どのような状況で発生していますか？',
    'affected_users' => '影響を受けているユーザー数や範囲を教えてください。',
    'attempted_solutions' => 'これまでに試された対処法があれば教えてください。',
    'inquiry_type' => 'どのようなご用件でしょうか？',
    'company_size' => '貴社の規模（従業員数等）を教えていただけますか？'
  }.freeze

  def initialize
    @inquiry_analyzer = InquiryAnalyzerService.new
  end

  # 初回メッセージを処理し、必要な情報を特定
  def process_initial_message(conversation, user_message)
    # カテゴリを判定
    category = categorize_inquiry(user_message)
    
    # 既に抽出できる情報を取得
    extracted_info = extract_information(user_message, category)
    
    # 必要な情報リストを生成
    required_info = determine_required_info(category, extracted_info)
    
    # 次の質問を生成
    next_question = generate_next_question(extracted_info, category)
    
    {
      category: category,
      required_info: required_info,
      collected_info: extracted_info,
      next_question: next_question,
      completion_rate: calculate_completion_rate(extracted_info, category)
    }
  end

  # 次の質問を生成
  def generate_next_question(collected_info, category)
    info_config = REQUIRED_INFO[category] || REQUIRED_INFO['general']
    
    # まず必須情報が全て揃っているか確認
    essential_missing = info_config[:essential].find do |info_key|
      value = collected_info[info_key] || collected_info[info_key.to_sym]
      value.nil? || (value.respond_to?(:empty?) && value.empty?)
    end
    
    # 必須情報に欠けがある場合はそれを優先
    if essential_missing
      return customize_question(QUESTION_TEMPLATES[essential_missing], collected_info)
    end
    
    # 必須情報が揃っている場合は、オプション情報は不要
    nil # 全ての必須情報が収集済み
  end

  # ユーザーメッセージから情報を抽出
  def extract_information(message, category)
    extracted = {}
    
    # 業界・事業タイプの抽出
    if message =~ /BtoB\s*SaaS/i
      extracted[:business_type] = 'BtoB SaaS'
    elsif message =~ /SaaS(?:企業|事業)?/
      extracted[:business_type] = 'SaaS'
    elsif message =~ /(?:小売|アパレル|EC|食品|製造|サービス|IT|不動産|医療|教育)業?/
      extracted[:business_type] = $&
    elsif message =~ /EC\s*(?:サイト|事業)/
      extracted[:business_type] = 'EC事業'
    elsif message =~ /(?:サイト|ショップ|店舗|会社|企業)を?(?:運営|経営|営業)/
      extracted[:business_type] = message[/[^、。\s]+(?:サイト|ショップ|店舗)/]
    end
    
    # 売上情報の抽出（広告費より先に処理）
    if message =~ /(?:月商|年商|売上).*?(\d+[\d,]*)\s*(?:万|千|億)?円/
      amount = $1.gsub(',', '')
      unit = $& =~ /億/ ? '億円' : $& =~ /千/ ? '千円' : '万円'
      prefix = $& =~ /月商/ ? '月商' : $& =~ /年商/ ? '年商' : '売上'
      extracted[:monthly_revenue] = "#{amount}#{unit}"
    end
    
    # 予算情報の抽出（月額を優先）
    if message =~ /月額.*?(\d+[\d,]*)\s*(?:万|千|億)?円/
      amount = $1.gsub(',', '')
      unit = $& =~ /億/ ? '億円' : $& =~ /千/ ? '千円' : '万円'
      extracted[:budget_range] = "月額#{amount}#{unit}"
    elsif message =~ /広告費.*?(\d+[\d,]*)\s*(?:万|千|億)?円/
      amount = $1.gsub(',', '')
      unit = $& =~ /億/ ? '億円' : $& =~ /千/ ? '千円' : '万円'
      prefix = message =~ /月/ ? '月' : ''
      extracted[:ad_spend] = "#{prefix}#{amount}#{unit}"
    elsif message =~ /(?:予算|費用).*?(\d+[\d,]*)\s*(?:万|千|億)?円/
      # 一般的な予算情報の抽出
      amount = $1.gsub(',', '')
      unit = $& =~ /億/ ? '億円' : $& =~ /千/ ? '千円' : '万円'
      prefix = message =~ /月/ ? '月額' : message =~ /年/ ? '年額' : ''
      extracted[:budget_range] = "#{prefix}#{amount}#{unit}"
    end
    
    # ツール名の抽出
    tools = []
    tool_patterns = [
      'Shopify', 'Google Analytics', 'GA4', 'Facebook', 'Instagram',
      'Twitter', 'LINE', 'Salesforce', 'HubSpot', 'Marketo',
      'WordPress', 'EC-CUBE', 'BASE', 'STORES', 'カラーミーショップ'
    ]
    
    tool_patterns.each do |tool|
      tools << tool if message.include?(tool)
    end
    
    extracted[:current_tools] = tools unless tools.empty?
    
    # システムタイプの抽出（技術系）
    if category == 'tech'
      if message =~ /(?:API|データベース|サーバー|フロントエンド|バックエンド|インフラ|システム)/
        extracted[:system_type] = $&
      end
      
      if message =~ /(?:エラー|不具合|障害|停止|遅延|タイムアウト)/
        extracted[:error_details] = message[/[^。]*(?:エラー|不具合|障害)[^。]*/] || '不具合が発生'
      end
    end
    
    extracted
  end

  # 会話を続けるべきか判定
  def should_continue_conversation?(metadata)
    ai_count = metadata['ai_interaction_count'] || 0
    
    # 5往復以上は継続しない
    return false if ai_count >= 5
    
    # 緊急度が高い場合は継続しない
    return false if metadata['urgency'] == 'high'
    
    # 必要情報が全て揃った場合は継続しない
    if metadata['collected_info']
      category = metadata['category'] || 'marketing'
      # 文字列キーとシンボルキーの両方に対応
      info_config = REQUIRED_INFO[category] || REQUIRED_INFO['general']
      
      # 必須情報が全て揃っているか確認
      all_essential_collected = info_config[:essential].all? do |info|
        value = metadata['collected_info'][info] || metadata['collected_info'][info.to_sym]
        !value.nil? && !(value.respond_to?(:empty?) && value.empty?)
      end
      
      return false if all_essential_collected
    end
    
    # 5往復未満なら継続
    true
  end

  # 収集情報のサマリーを生成
  def generate_summary(collected_info, category)
    summary = "ご相談内容を確認させていただきました。\n\n"
    
    summary += "【お客様情報】\n"
    
    # 文字列キーとシンボルキーの両方に対応
    business_type = collected_info['business_type'] || collected_info[:business_type]
    if business_type
      summary += "・業界/事業: #{business_type}\n"
    end
    
    budget_range = collected_info['budget_range'] || collected_info[:budget_range]
    if budget_range
      summary += "・ご予算: #{budget_range}\n"
    end
    
    current_tools = collected_info['current_tools'] || collected_info[:current_tools]
    if current_tools
      tools_str = current_tools.is_a?(Array) ? 
                  current_tools.join(', ') : 
                  current_tools
      summary += "・利用中のツール: #{tools_str}\n"
    end
    
    challenges = collected_info['challenges'] || collected_info[:challenges]
    if challenges
      summary += "・課題: #{challenges}\n"
    end
    
    summary += "\n専門のスタッフが詳細なご提案をさせていただきます。"
    summary += "しばらくお待ちください。"
    
    summary
  end

  # 次のアクションを決定
  def determine_next_action(metadata)
    ai_count = metadata['ai_interaction_count'] || 0
    
    # 会話回数が上限に達した
    return :escalate_to_human if ai_count >= 5
    
    # 緊急度が高い
    return :escalate_to_human if metadata['urgency'] == 'high'
    
    # 必要情報が揃った
    if metadata['collected_info']
      category = metadata['category'] || 'marketing'
      info_config = REQUIRED_INFO[category] || REQUIRED_INFO['general']
      
      # 必須情報が全て揃っているか確認
      all_essential_collected = info_config[:essential].all? do |info|
        value = metadata['collected_info'][info] || metadata['collected_info'][info.to_sym]
        !value.nil? && !(value.respond_to?(:empty?) && value.empty?)
      end
      
      return :escalate_to_human if all_essential_collected
    end
    
    :continue_conversation
  end

  # 文脈を考慮した応答を生成
  def build_context_aware_response(conversation_history, collected_info, category)
    # 最新のユーザーメッセージから新しい情報を抽出
    if conversation_history.last && conversation_history.last[:role] == 'user'
      new_info = extract_information(conversation_history.last[:content], category)
      collected_info.merge!(new_info)
    end
    
    # まだ聞いていない情報について質問
    next_question = generate_next_question(collected_info, category)
    
    if next_question
      response = build_acknowledgment(collected_info) + "\n\n"
      response += next_question
    else
      response = generate_summary(collected_info, category)
    end
    
    response
  end

  # 問い合わせカテゴリを判定
  def categorize_inquiry(message)
    # マーケティング関連キーワード
    if message =~ /広告|マーケティング|SEO|CVR|売上|集客|EC|コンバージョン|リード|キャンペーン/
      return 'marketing'
    end
    
    # 技術関連キーワード
    if message =~ /API|エラー|不具合|システム|サーバー|データベース|バグ|障害|連携|統合/
      return 'tech'
    end
    
    'general'
  end
  
  # 統合テスト用のヘルパーメソッド
  def process_message(conversation, message_text)
    # メタデータの初期化
    conversation.metadata ||= {}
    
    # カテゴリを判定（初回のみ）
    if conversation.metadata['category'].nil?
      conversation.metadata['category'] = categorize_inquiry(message_text)
    end
    
    category = conversation.metadata['category']
    
    # 既存の収集情報を取得
    collected_info = conversation.metadata['collected_info'] || {}
    
    # メッセージから新しい情報を抽出
    new_info = extract_information(message_text, category)
    
    # 情報をマージ（シンボルを文字列キーに変換）
    new_info.each do |key, value|
      collected_info[key.to_s] = value
    end
    
    # 緊急度判定
    if message_text =~ /至急|緊急|すぐに|今すぐ|システム.*ダウン|業務.*止|全体.*ダウン/
      conversation.metadata['urgency'] = 'high'
    end
    
    # AIインタラクション回数を増加
    conversation.metadata['ai_interaction_count'] ||= 0
    conversation.metadata['ai_interaction_count'] += 1
    
    # 収集情報を更新
    conversation.metadata['collected_info'] = collected_info
    
    # 次のアクションを決定
    next_action = determine_next_action(conversation.metadata)
    
    # エスカレーションが必要な場合
    if next_action == :escalate_to_human
      # エスカレーションサービスを呼び出し
      @escalation_service ||= EscalationService.new
      escalation_result = @escalation_service.trigger_escalation(conversation, conversation.metadata)
      
      # メタデータが更新されているので再読み込み
      conversation.reload
      
      # サマリーを返す
      return {
        auto_response: generate_summary(collected_info, category),
        continue_conversation: false,
        metadata: conversation.metadata,
        escalation_result: escalation_result
      }
    end
    
    # 次の質問を生成
    next_question = generate_next_question(collected_info, category)
    
    # 会話を保存
    conversation.save!
    
    # 応答を返す
    {
      auto_response: next_question || generate_summary(collected_info, category),
      continue_conversation: should_continue_conversation?(conversation.metadata),
      metadata: conversation.metadata
    }
  end
  
  # メタデータを更新するヘルパー
  def update_conversation_metadata(conversation, extracted_info)
    conversation.metadata ||= {}
    conversation.metadata['collected_info'] ||= {}
    
    # 抽出した情報をマージ
    extracted_info.each do |key, value|
      conversation.metadata['collected_info'][key.to_s] = value
    end
    
    conversation.save!
  end
  
  # エスカレーションが必要かチェック
  def check_for_escalation(conversation, metadata)
    return unless should_escalate?(metadata)
    
    @escalation_service ||= EscalationService.new
    @escalation_service.trigger_escalation(conversation, metadata)
  end
  
  # エスカレーションが必要か判定
  def should_escalate?(metadata)
    # 既にエスカレーション済みの場合はfalse
    return false if metadata['escalated_at'].present?
    
    # 緊急度が高い
    return true if metadata['urgency'] == 'high'
    
    # 5往復に達した
    return true if (metadata['ai_interaction_count'] || 0) >= 5
    
    # 必要情報が揃った
    if metadata['category'] == 'marketing' && metadata['collected_info']
      required_fields = %w[business_type budget_range current_tools]
      collected_fields = metadata['collected_info'].keys
      return true if (required_fields - collected_fields).empty?
    end
    
    false
  end
  
  # メッセージから情報を抽出するヘルパー
  def extract_info_from_message(message_text)
    category = categorize_inquiry(message_text)
    extract_information(message_text, category)
  end

  private

  # 必要な情報を決定
  def determine_required_info(category, collected_info)
    info_config = REQUIRED_INFO[category] || REQUIRED_INFO['general']
    required = []
    
    # 必須情報のうち未収集のもの
    info_config[:essential].each do |info|
      value = collected_info[info.to_sym] || collected_info[info]
      required << info if value.nil? || (value.respond_to?(:empty?) && value.empty?)
    end
    
    # オプション情報のうち未収集のもの
    info_config[:optional].each do |info|
      value = collected_info[info.to_sym] || collected_info[info]
      required << info if value.nil? || (value.respond_to?(:empty?) && value.empty?)
    end
    
    required
  end

  # 完了率を計算
  def calculate_completion_rate(collected_info, category)
    info_config = REQUIRED_INFO[category] || REQUIRED_INFO['general']
    essential_count = info_config[:essential].count
    
    return 0 if essential_count == 0
    
    collected_essential = info_config[:essential].count do |info|
      !collected_info[info].nil? && !collected_info[info].empty?
    end
    
    (collected_essential.to_f / essential_count * 100).round
  end

  # 質問をカスタマイズ
  def customize_question(template, collected_info)
    return template unless template
    
    # 既に収集した情報に基づいて質問を調整
    if collected_info[:business_type] && template.include?('業界')
      template = template.gsub('業界・事業', collected_info[:business_type].to_s + 'における具体的な事業内容')
    end
    
    template
  end

  # 認識した情報への確認メッセージを生成
  def build_acknowledgment(collected_info)
    ack = ''
    
    if collected_info[:business_type] && !@acknowledged_business
      ack += "#{collected_info[:business_type]}を運営されているのですね。"
      @acknowledged_business = true
    end
    
    if collected_info[:budget_range] && !@acknowledged_budget
      ack += "ご予算は#{collected_info[:budget_range]}程度とのこと、承知いたしました。"
      @acknowledged_budget = true
    end
    
    ack.empty? ? 'ありがとうございます。' : ack
  end
end