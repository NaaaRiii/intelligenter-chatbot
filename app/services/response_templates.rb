# frozen_string_literal: true

# ボット応答テンプレート管理クラス
class ResponseTemplates
  attr_reader :intent_type, :context, :template_id

  # テンプレート定義
  TEMPLATES = {
    greeting: [
      'こんにちは、{user_name}！本日はどのようなご用件でしょうか？',
      '{user_name}、お疲れ様です。何かお手伝いできることはございますか？',
      'いらっしゃいませ、{user_name}。ご質問やお困りのことがございましたらお聞かせください。'
    ],
    question: [
      'ご質問ありがとうございます。詳しく確認させていただきます。',
      'お問い合わせいただいた件について、確認いたします。',
      'ご質問の内容を承りました。順番に回答させていただきます。'
    ],
    complaint: [
      'ご不便をおかけして申し訳ございません。詳細を確認させていただきます。',
      'お困りの状況について、心よりお詫び申し上げます。すぐに対応させていただきます。',
      'ご迷惑をおかけして大変申し訳ございません。問題解決に向けて全力で対応いたします。'
    ],
    feedback: [
      '貴重なフィードバックをありがとうございます。',
      'ご意見をいただき、誠にありがとうございます。サービス改善の参考にさせていただきます。',
      'フィードバックを共有いただきありがとうございます。今後の改善に活かさせていただきます。'
    ],
    general: [
      'メッセージありがとうございます。どのようにお手伝いできますでしょうか？',
      'ご連絡ありがとうございます。ご用件をお聞かせください。',
      'お問い合わせありがとうございます。詳細をお教えいただけますでしょうか？'
    ]
  }.freeze

  # 時間帯別の挨拶
  TIME_GREETINGS = {
    morning: 'おはようございます',
    afternoon: 'こんにちは',
    evening: 'こんばんは',
    night: 'お疲れ様です'
  }.freeze

  def initialize(intent_type:, context: {})
    @intent_type = intent_type.to_sym
    @context = context
    @template_id = nil
  end

  # 応答を取得
  def response
    template = select_template
    personalize_response(template)
  end

  # 利用可能なテンプレート数を取得
  def available_templates_count
    TEMPLATES[@intent_type]&.size || 0
  end

  private

  # テンプレートを選択
  def select_template
    templates = TEMPLATES[@intent_type] || TEMPLATES[:general]

    # コンテキストに基づいて最適なテンプレートを選択
    template_index = select_best_template_index(templates)
    @template_id = "#{@intent_type}_#{template_index}"

    templates[template_index]
  end

  # 最適なテンプレートインデックスを選択
  def select_best_template_index(templates)
    # メッセージ数に基づいて変化を持たせる
    message_count = @context[:message_count] || 0

    # 会話の長さに応じて異なるテンプレートを使用
    case message_count
    when 0..2
      0 # 初回は最初のテンプレート
    when 3..5
      [1, templates.size - 1].min # 2番目のテンプレート
    else
      rand(templates.size) # ランダムに選択
    end
  end

  # 応答をパーソナライズ
  def personalize_response(template)
    response = template.dup

    # プレースホルダーを置換
    response.gsub!('{user_name}', @context[:user_name] || 'お客様')

    # 時間帯の挨拶を追加
    if @intent_type == :greeting && @context[:time_of_day]
      time_greeting = TIME_GREETINGS[@context[:time_of_day].to_sym]
      response = "#{time_greeting}、#{response}" if time_greeting
    end

    # キーワードに基づく追加情報
    response = add_keyword_context(response, @context[:intent_keywords]) if @context[:intent_keywords]&.any?

    response
  end

  # キーワードコンテキストを追加
  def add_keyword_context(response, keywords)
    keyword_responses = {
      '料金' => '料金に関するお問い合わせですね。',
      '使い方' => '使用方法についてご案内いたします。',
      'エラー' => 'エラーが発生しているようですね。',
      '解約' => '解約をご検討されているのですね。',
      'アップグレード' => 'アップグレードについてご案内いたします。'
    }

    keywords.each do |keyword|
      keyword_responses.each do |key, value|
        return "#{value}#{response}" if keyword.include?(key)
      end
    end

    response
  end
end
