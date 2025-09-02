# frozen_string_literal: true

class ResponseTemplateService
  # カテゴリ定義
  CATEGORIES = {
    pricing: '料金',
    features: '機能',
    support: 'サポート',
    onboarding: '導入',
    general: '一般'
  }.freeze
  
  # テンプレート構造
  TEMPLATE_STRUCTURES = {
    standard: [:greeting, :main_content, :call_to_action],
    support: [:acknowledgment, :troubleshooting, :escalation],
    sales: [:value_proposition, :benefits, :pricing, :next_steps]
  }.freeze
  
  # トーン設定
  TONES = {
    professional: { formality: 'high', friendliness: 'medium' },
    empathetic: { formality: 'medium', friendliness: 'high', understanding: 'high' },
    premium: { formality: 'high', exclusivity: 'high', personalization: 'high' }
  }.freeze
  
  def initialize
    @template_cache = {}
    @performance_data = {}
  end
  
  # テンプレートを生成
  def generate_template(context_data)
    category = context_data[:category]&.to_sym || :general
    
    base_template = load_base_template(category)
    
    # カテゴリ別の処理
    template = case category
    when :pricing
      generate_pricing_template(context_data, base_template)
    when :features
      generate_features_template(context_data, base_template)
    when :support
      generate_support_template(context_data, base_template)
    when :onboarding
      generate_onboarding_template(context_data, base_template)
    else
      generate_general_template(context_data, base_template)
    end
    
    # バリエーションを追加
    template[:variations] = generate_variations(template)
    
    template
  end
  
  # テンプレートを適用
  def apply_template(template)
    content = template[:content].dup
    placeholders = template[:placeholders] || {}
    
    # プレースホルダーを置換
    placeholders.each do |key, value|
      content.gsub!("{#{key}}", value.to_s)
    end
    
    # 動的な値を適用
    if template[:dynamic_values]
      template[:dynamic_values].each do |key, value_proc|
        value = value_proc.is_a?(Proc) ? value_proc.call : value_proc
        content.gsub!("{#{key}}", value.to_s)
      end
    end
    
    content
  end
  
  # 会話をカテゴライズ
  def categorize_conversation(messages)
    categories_found = []
    
    messages.each do |msg|
      content = msg[:content] || msg['content'] || ''
      
      # カテゴリキーワードをチェック
      if content =~ /料金|価格|費用|プラン|コスト/
        categories_found << :pricing
      end
      if content =~ /機能|できる|使える|可能/
        categories_found << :features
      end
      if content =~ /エラー|問題|動かない|困って/
        categories_found << :support
      end
      if content =~ /導入|始める|開始|契約/
        categories_found << :onboarding
      end
    end
    
    primary = categories_found.max_by { |cat| categories_found.count(cat) } || :general
    secondary = (categories_found - [primary]).first
    
    {
      primary: primary.to_s,
      secondary: secondary&.to_s,
      confidence: calculate_confidence(categories_found),
      sub_categories: determine_sub_categories(primary),
      mixed: categories_found.uniq.size > 1
    }
  end
  
  # 成功したテンプレートを読み込み
  def load_successful_templates(category)
    templates = []
    
    KnowledgeBase.where("content->>'category' = ?", category)
                 .where('success_score >= ?', 80)
                 .order(success_score: :desc).each do |kb|
      
      template_data = {
        template: kb.content['template'] || '',
        category: kb.content['category'],
        success_score: kb.success_score,
        tags: kb.tags
      }
      
      templates << template_data
    end
    
    templates
  end
  
  # コンテキストに合わせてカスタマイズ
  def customize_for_context(base_template, context_info)
    customized = base_template.dup
    
    # VIP顧客向けカスタマイズ
    if context_info[:customer_type] == 'vip'
      customized[:tone] = 'premium'
      customized[:personalization_level] = 'high'
      customized[:additional_offers] = generate_vip_offers
    end
    
    # 緊急度による調整
    if context_info[:urgency] == 'critical'
      customized[:priority] = 'immediate'
      customized[:escalation_included] = true
      customized[:response_time_commitment] = '30分以内に対応'
    end
    
    # 履歴による調整
    if context_info[:history] == 'long_term' && context_info[:satisfaction] == 'high'
      customized[:loyalty_rewards] = true
      customized[:special_mentions] = '長年のご愛顧に感謝'
    end
    
    customized
  end
  
  # テンプレートを検証
  def validate_template(template)
    errors = []
    warnings = []
    unmatched = []
    
    content = template[:content] || ''
    placeholders = template[:placeholders] || {}
    
    # プレースホルダーのチェック
    content.scan(/\{(\w+)\}/).flatten.each do |placeholder|
      unless placeholders.key?(placeholder.to_sym) || placeholders.key?(placeholder)
        errors << 'missing_placeholder'
        unmatched << placeholder
      end
    end
    
    # カテゴリチェック
    unless template[:category]
      warnings << 'missing_category'
    end
    
    {
      valid: errors.empty?,
      errors: errors,
      warnings: warnings,
      unmatched_placeholders: unmatched
    }
  end
  
  # テンプレートをマージ
  def merge_templates(templates)
    merged = {
      content: '',
      sections: [],
      merged_from: templates.size
    }
    
    templates.each do |template|
      merged[:content] += template[:content] + "\n"
      merged[:sections].concat(template[:sections] || [])
    end
    
    merged[:sections].uniq!
    merged[:content].strip!
    
    merged
  end
  
  # チャネル用に最適化
  def optimize_for_channel(template, channel)
    optimized = template.dup
    
    case channel
    when 'chat'
      # チャット用の最適化
      if template[:content].length > 500
        optimized[:split_messages] = split_long_message(template[:content])
        optimized[:content] = optimized[:split_messages].first
      end
      optimized[:formatting] = 'plain'
      
    when 'email'
      # メール用の最適化
      optimized[:subject] = generate_email_subject(template)
      optimized[:formatting] = 'html'
      optimized[:includes_signature] = true
      
    when 'sms'
      # SMS用の最適化
      optimized[:content] = template[:content][0..159]
      optimized[:formatting] = 'plain'
    end
    
    optimized
  end
  
  # テンプレートパフォーマンスを追跡
  def track_template_performance(template:, conversation:, outcome:)
    template_id = template[:id] || generate_template_id(template)
    
    @performance_data[template_id] ||= {
      usage_count: 0,
      successful: 0,
      failed: 0,
      last_used: nil
    }
    
    @performance_data[template_id][:usage_count] += 1
    @performance_data[template_id][:successful] += 1 if outcome == 'successful'
    @performance_data[template_id][:failed] += 1 if outcome == 'failed'
    @performance_data[template_id][:last_used] = Time.current
    
    # 成功率を計算
    data = @performance_data[template_id]
    success_rate = data[:usage_count] > 0 ? data[:successful].to_f / data[:usage_count] : 0
    
    {
      usage_count: data[:usage_count],
      success_rate: success_rate,
      last_used: data[:last_used]
    }
  end
  
  # テンプレート統計を取得
  def get_template_statistics(template_id)
    data = @performance_data[template_id] || {}
    
    return { total_uses: 0, success_rate: 0, trending: 'stable' } if data.empty?
    
    {
      total_uses: data[:usage_count],
      success_rate: data[:usage_count] > 0 ? data[:successful].to_f / data[:usage_count] : 0,
      trending: determine_trend(data)
    }
  end
  
  # 改善提案を生成
  def suggest_improvements(template)
    suggestions = {
      recommended_changes: [],
      similar_high_performers: [],
      priority: 'low'
    }
    
    # パフォーマンスが低い場合
    if template[:performance] && template[:performance][:success_rate] < 0.5
      suggestions[:priority] = 'high'
      suggestions[:recommended_changes] << 'より明確な説明を追加'
      suggestions[:recommended_changes] << 'カスタマイゼーションを強化'
      
      # 高パフォーマンステンプレートを検索
      high_performers = KnowledgeBase.where("content->>'category' = ?", template[:category])
                                      .where('success_score > ?', 85)
                                      .limit(3)
      
      suggestions[:similar_high_performers] = high_performers.map do |hp|
        {
          template: hp.content['template'],
          score: hp.success_score
        }
      end
    end
    
    suggestions
  end
  
  private
  
  # ベーステンプレートを読み込み
  def load_base_template(category)
    {
      category: category,
      structure: TEMPLATE_STRUCTURES[:standard],
      tone: 'professional'
    }
  end
  
  # 料金テンプレートを生成
  def generate_pricing_template(context_data, base)
    template = base.merge(
      content: '料金プランについてご案内いたします。',
      structure: [:greeting, :main_content, :call_to_action],
      variations: []
    )
    
    if context_data[:customer_type] == 'new'
      template[:content] = 'はじめてのお客様向けの料金プランをご案内いたします。'
    end
    
    template
  end
  
  # 機能テンプレートを生成
  def generate_features_template(context_data, base)
    feature = context_data[:specific_feature] || 'general'
    
    template = base.merge(
      content: "#{feature == 'analytics' ? '分析機能' : '機能'}についてご説明いたします。",
      key_points: ['データ可視化', 'リアルタイム分析', 'レポート生成'],
      examples: ['売上分析', '顧客行動分析'],
      difficulty_level: 'intermediate'
    )
    
    template
  end
  
  # サポートテンプレートを生成
  def generate_support_template(context_data, base)
    template = base.merge(
      content: 'お困りの状況について承知いたしました。',
      tone: 'empathetic',
      escalation_ready: context_data[:urgency] == 'high',
      troubleshooting_steps: ['状況確認', '基本的な解決策', 'エスカレーション']
    )
    
    template
  end
  
  # 導入テンプレートを生成
  def generate_onboarding_template(context_data, base)
    company_size = context_data[:company_size] || 'medium'
    
    template = base.merge(
      content: "導入についてご相談承ります。#{company_size == 'enterprise' ? 'エンタープライズ向けのご提案をいたします。' : ''}",
      customization_options: ['カスタムプラン', '専任サポート'],
      compliance_mentions: ['セキュリティ', 'コンプライアンス']
    )
    
    template
  end
  
  # 一般テンプレートを生成
  def generate_general_template(context_data, base)
    base.merge(
      content: 'ご質問ありがとうございます。'
    )
  end
  
  # バリエーションを生成
  def generate_variations(template)
    [
      template[:content],
      template[:content] + ' 詳細はこちらです。',
      'ご不明な点がございましたら、' + template[:content]
    ]
  end
  
  # 信頼度を計算
  def calculate_confidence(categories_found)
    return 0.3 if categories_found.empty?
    return 0.9 if categories_found.size == 1
    
    # 最頻出カテゴリの割合
    max_count = categories_found.group_by(&:itself).values.map(&:size).max
    max_count.to_f / categories_found.size
  end
  
  # サブカテゴリを決定
  def determine_sub_categories(primary)
    case primary
    when :pricing
      ['plan_comparison', 'discount_inquiry', 'payment_methods']
    when :features
      ['core_features', 'integrations', 'customization']
    when :support
      ['technical_issue', 'account_issue', 'billing_issue']
    else
      []
    end
  end
  
  # VIPオファーを生成
  def generate_vip_offers
    [
      '専任アカウントマネージャー',
      '優先サポート',
      '特別割引'
    ]
  end
  
  # 長いメッセージを分割
  def split_long_message(content, max_length = 500)
    messages = []
    current = ''
    
    content.split(/[。！？]/).each do |sentence|
      if (current + sentence).length > max_length
        messages << current.strip
        current = sentence
      else
        current += sentence + '。'
      end
    end
    
    messages << current.strip if current.present?
    messages
  end
  
  # メール件名を生成
  def generate_email_subject(template)
    category_subjects = {
      pricing: '料金プランのご案内',
      features: '機能についてのご説明',
      support: 'サポートチケット',
      onboarding: '導入のご相談'
    }
    
    category_subjects[template[:category]] || 'お問い合わせへの回答'
  end
  
  # テンプレートIDを生成
  def generate_template_id(template)
    "template_#{template[:category]}_#{Time.current.to_i}"
  end
  
  # トレンドを判定
  def determine_trend(data)
    # 簡易的な実装
    return 'stable' unless data[:usage_count] > 10
    
    success_rate = data[:successful].to_f / data[:usage_count]
    
    return 'up' if success_rate > 0.7
    return 'down' if success_rate < 0.3
    'stable'
  end
end