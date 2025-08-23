# frozen_string_literal: true

require 'capybara/rails'
require 'capybara/rspec'
require 'selenium-webdriver'

# Capybara設定
Capybara.configure do |config|
  config.default_driver = :rack_test
  config.javascript_driver = :selenium_chrome_headless
  config.default_max_wait_time = 5
  config.server = :puma, { Silent: true }
  # ランダムなポートを使用（テスト並列実行対応）
  config.server_port = nil
  config.server_host = '127.0.0.1'
  config.app_host = 'http://127.0.0.1'
end

# Chrome Headless設定
Capybara.register_driver :selenium_chrome_headless do |app|
  options = Selenium::WebDriver::Chrome::Options.new
  options.add_argument('--headless=new')
  options.add_argument('--no-sandbox')
  options.add_argument('--disable-dev-shm-usage')
  options.add_argument('--disable-gpu')
  options.add_argument('--window-size=1920,1080')
  options.add_argument('--disable-blink-features=AutomationControlled')
  options.add_argument('--user-agent=Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36')
  # テスト用のログレベル設定
  options.add_argument('--log-level=3') # エラーログのみ
  options.add_argument('--silent')

  Capybara::Selenium::Driver.new(
    app,
    browser: :chrome,
    options: options,
    clear_session_storage: true,
    clear_local_storage: true
  )
end

# システムテスト用の設定
RSpec.configure do |config|
  config.before(:each, type: :system) do
    driven_by :selenium_chrome_headless
  end

  config.before(:each, :js, type: :system) do
    driven_by :selenium_chrome_headless
    
    # ウィンドウサイズを設定
    page.driver.browser.manage.window.resize_to(1920, 1080) if page.driver.browser.respond_to?(:manage)
  rescue StandardError
    # ドライバーがウィンドウ管理をサポートしていない場合は無視
  end

  config.after(:each, type: :system, js: true) do
    # セッションをクリア
    Capybara.reset_sessions!
  rescue StandardError
    # エラーが発生してもテストを続行
  end
end
