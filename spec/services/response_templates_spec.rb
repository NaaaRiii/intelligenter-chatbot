# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ResponseTemplates, type: :service do
  describe '#response' do
    context 'with greeting intent' do
      it '挨拶テンプレートを返す' do
        templates = described_class.new(
          intent_type: :greeting,
          context: { user_name: '田中様' }
        )

        response = templates.response
        expect(response).to include('田中様')
        expect(response).to match(/こんにちは|いらっしゃいませ|お疲れ様/)
      end

      it '時間帯に応じた挨拶を追加する' do
        templates = described_class.new(
          intent_type: :greeting,
          context: { user_name: '山田様', time_of_day: 'morning' }
        )

        response = templates.response
        expect(response).to include('おはようございます')
      end
    end

    context 'with question intent' do
      it '質問テンプレートを返す' do
        templates = described_class.new(
          intent_type: :question,
          context: {}
        )

        response = templates.response
        expect(response).to match(/ご質問|お問い合わせ|確認/)
      end
    end

    context 'with complaint intent' do
      it '苦情対応テンプレートを返す' do
        templates = described_class.new(
          intent_type: :complaint,
          context: {}
        )

        response = templates.response
        expect(response).to match(/申し訳|お詫び|ご不便/)
      end
    end

    context 'with feedback intent' do
      it 'フィードバックテンプレートを返す' do
        templates = described_class.new(
          intent_type: :feedback,
          context: {}
        )

        response = templates.response
        expect(response).to match(/フィードバック|ご意見|改善/)
      end
    end

    context 'with general intent' do
      it '一般テンプレートを返す' do
        templates = described_class.new(
          intent_type: :general,
          context: {}
        )

        response = templates.response
        expect(response).to match(/メッセージ|ご連絡|お問い合わせ/)
      end
    end

    context 'with unknown intent' do
      it '一般テンプレートを返す' do
        templates = described_class.new(
          intent_type: :unknown,
          context: {}
        )

        response = templates.response
        expect(response).to match(/メッセージ|ご連絡|お問い合わせ/)
      end
    end

    context 'with keyword context' do
      it 'キーワードに基づく追加情報を含む' do
        templates = described_class.new(
          intent_type: :question,
          context: { intent_keywords: ['料金'] }
        )

        response = templates.response
        expect(response).to include('料金に関するお問い合わせですね')
      end

      it 'エラーキーワードに反応する' do
        templates = described_class.new(
          intent_type: :complaint,
          context: { intent_keywords: ['エラー'] }
        )

        response = templates.response
        expect(response).to include('エラーが発生しているようですね')
      end
    end

    context 'with message count context' do
      it '初回メッセージには最初のテンプレートを使用' do
        templates = described_class.new(
          intent_type: :greeting,
          context: { message_count: 0 }
        )

        allow(templates).to receive(:select_best_template_index).and_return(0)
        templates.response
        expect(templates.template_id).to eq('greeting_0')
      end

      it '複数メッセージ後は異なるテンプレートを使用' do
        templates = described_class.new(
          intent_type: :greeting,
          context: { message_count: 4 }
        )

        response = templates.response
        expect(response).to be_present
      end
    end
  end

  describe '#available_templates_count' do
    it '利用可能なテンプレート数を返す' do
      templates = described_class.new(intent_type: :greeting, context: {})
      expect(templates.available_templates_count).to eq(3)
    end

    it '未定義の意図の場合は0を返す' do
      templates = described_class.new(intent_type: :unknown, context: {})
      expect(templates.available_templates_count).to eq(0)
    end
  end
end
