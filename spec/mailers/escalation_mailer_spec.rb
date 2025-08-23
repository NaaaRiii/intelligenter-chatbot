require 'rails_helper'

RSpec.describe EscalationMailer, type: :mailer do
  describe 'alert' do
    let(:conversation_id) { 123 }
    let(:summary) { '優先度: high, 感情: frustrated, 推奨アクション: キャッシュ機能の導入' }
    let(:mail) { described_class.alert(conversation_id: conversation_id, summary: summary) }

    it 'renders the headers' do
      expect(mail.subject).to eq("【要対応】会話ID: #{conversation_id}")
      expect(mail.to).to eq(['cs-team@example.com'])
      expect(mail.from).to eq(['noreply@example.com'])
    end

    it 'renders the body' do
      # HTMLパート
      html_part = mail.html_part.body.decoded
      expect(html_part).to include(conversation_id.to_s)
      expect(html_part).to include(summary)

      # テキストパート
      text_part = mail.text_part.body.decoded
      expect(text_part).to include(conversation_id.to_s)
      expect(text_part).to include(summary)
    end
  end
end
