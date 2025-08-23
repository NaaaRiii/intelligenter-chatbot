class EscalationMailer < ApplicationMailer
  default from: 'noreply@example.com'

  def alert(conversation_id:, summary:)
    @conversation_id = conversation_id
    @summary = summary

    mail(
      to: 'cs-team@example.com',
      subject: "【要対応】会話ID: #{conversation_id}"
    )
  end
end
