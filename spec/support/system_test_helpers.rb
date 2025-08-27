# frozen_string_literal: true

module SystemTestHelpers
  # 複数のブラウザセッションをシミュレート
  def in_browser(name)
    old_session = Capybara.session_name
    Capybara.session_name = name
    yield
  ensure
    Capybara.session_name = old_session
  end

  # ActionCableの接続を待つ
  def wait_for_websocket
    expect(page).to have_css('[data-channel]', wait: 5)
  end

  # 分析完了を待つ
  def wait_for_analysis_complete
    expect(page).to have_css('.analysis-complete', wait: 10)
  end

  # Sidekiqジョブの実行を待つ
  def wait_for_jobs_to_complete
    Timeout.timeout(10) do
      sleep 0.1 while Sidekiq::Worker.jobs.any?
    end
  end

  # モーダルの表示を待つ
  def wait_for_modal
    expect(page).to have_css('.modal', wait: 3)
  end

  # Ajax完了を待つ
  def wait_for_ajax
    Timeout.timeout(Capybara.default_max_wait_time) do
      loop until page.evaluate_script('jQuery.active').zero?
    end
  end

  # トーストメッセージを確認
  def expect_toast_message(message)
    expect(page).to have_css('.toast', text: message, wait: 5)
  end

  # プログレスバーの進捗を確認
  def expect_progress(percentage)
    expect(page).to have_css(".progress-bar[style*='width: #{percentage}%']")
  end

  # デバッグ用スクリーンショット
  def debug_screenshot(name = 'debug')
    # rubocop:disable Lint/Debugger
    save_screenshot("tmp/#{name}_#{Time.now.to_i}.png") if ENV['DEBUG_SCREENSHOTS']
    # rubocop:enable Lint/Debugger
  end
end

RSpec.configure do |config|
  config.include SystemTestHelpers, type: :system
end