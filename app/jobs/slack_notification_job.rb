# frozen_string_literal: true

class SlackNotificationJob < ApplicationJob
  queue_as :notifications

  def perform(category:, customer_name:, message:, conversation_id:)
    SlackNotifierService.notify_new_inquiry(
      category: category,
      customer_name: customer_name,
      message: message,
      conversation_id: conversation_id
    )
  rescue StandardError => e
    Rails.logger.error "SlackNotificationJob failed: #{e.message}"
    Rails.logger.error e.backtrace.join("\n")
  end
end