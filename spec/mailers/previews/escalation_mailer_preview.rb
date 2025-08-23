class EscalationMailerPreview < ActionMailer::Preview
  delegate :alert, to: :escalation_mailer

  private

  def escalation_mailer = EscalationMailer
end
