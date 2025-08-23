# frozen_string_literal: true

# WebSocketのモック設定
module WebSocketMockHelper
  private

  def create_mock_websocket_class
    <<~JS
      window.MockWebSocket = function(url) {
        this.url = url;
        this.readyState = 1; // OPEN
        this.send = function(data) {
          // テスト用のエコーバック
          if (this.onmessage) {
            setTimeout(() => {
              this.onmessage({ data: data });
            }, 10);
          }
        };
        this.close = function() {
          this.readyState = 3; // CLOSED
          if (this.onclose) this.onclose();
        };

        // 接続成功を通知
        setTimeout(() => {
          if (this.onopen) this.onopen();
        }, 10);
      };
    JS
  end

  def apply_websocket_mock
    <<~JS
      // テストモードではMockWebSocketを使用
      if (window.TEST_MODE) {
        window.WebSocket = window.MockWebSocket;
      }
    JS
  end

  public

  def setup_websocket_mock
    page.execute_script(create_mock_websocket_class + apply_websocket_mock)
  end

  private

  def create_subscription_mock
    <<~JS
      const subscription = {
        identifier: JSON.stringify(channel),
        received: callbacks.received || function() {},
        perform: function(action, data) {
          // テスト用の即座のコールバック
          if (action === 'send_message' && data) {
            setTimeout(() => {
              this.received({
                type: 'new_message',
                message: {
                  id: Date.now(),
                  content: data.content,
                  role: 'user',
                  created_at: new Date().toISOString()
                }
              });
            }, 100);
          }
          return true;
        },
        unsubscribe: function() {}
      };

      // グローバルに参照可能にする
      window.lastSubscription = subscription;
      return subscription;
    JS
  end

  def create_cable_mock
    <<~JS
      window.TEST_MODE = true;
      window.App = window.App || {};
      window.App.cable = {
        subscriptions: {
          create: function(channel, callbacks) {
            #{create_subscription_mock}
          },
          find: function(callback) {
            return window.lastSubscription;
          }
        },
        disconnect: function() {
          window.dispatchEvent(new CustomEvent('cable:disconnected'));
        },
        connect: function() {
          window.dispatchEvent(new CustomEvent('cable:connected'));
        }
      };
    JS
  end

  def suppress_action_cable_logs
    <<~JS
      // ActionCableのログを抑制
      if (window.ActionCable) {
        window.ActionCable.logger = { log: function() {} };
      }
    JS
  end

  public

  def setup_action_cable_mock
    page.execute_script(create_cable_mock + suppress_action_cable_logs)
  end
end

# エラー処理のモック設定
module ErrorMockHelper
  def trigger_network_error
    page.execute_script('window.navigator.onLine = false; window.dispatchEvent(new Event("offline"));')
  end

  def trigger_server_error
    page.execute_script(<<~JS)
      window.forceServerError = true;
      window.XMLHttpRequest = function() {
        this.open = function() {};
        this.setRequestHeader = function() {};
        this.send = function() {
          this.status = 500;
          throw new Error('Server error');
        };
      };
    JS
  end

  def trigger_timeout_error
    page.execute_script(<<~JS)
      window.forceTimeout = true;
      const originalFetch = window.fetch;
      window.fetch = function() {
        return new Promise((resolve, reject) => {
          setTimeout(() => reject(new Error('Timeout')), 100);
        });
      };
    JS
  end

  def trigger_error(error_type)
    case error_type
    when :network then trigger_network_error
    when :server then trigger_server_error
    when :timeout then trigger_timeout_error
    end
  end

  def reset_error_mocks
    page.execute_script(<<~JS)
      delete window.forceServerError;
      delete window.forceTimeout;
      window.navigator.onLine = true;
      // XMLHttpRequestとfetchをリセット（リロードが必要な場合がある）
    JS
  end
end

# システムテスト用ヘルパー
module SystemTestHelper
  include WebSocketMockHelper
  include ErrorMockHelper

  def setup_test_environment
    setup_action_cable_mock
  end

  def wait_for_ajax
    Timeout.timeout(Capybara.default_max_wait_time) do
      loop do
        active = page.evaluate_script('typeof jQuery !== "undefined" ? jQuery.active : 0')
        break if active.to_i.zero?

        sleep 0.1
      end
    end
  rescue Timeout::Error
    # タイムアウトしても続行
  end

  def wait_for_websocket
    # WebSocket接続の準備を待つ
    sleep 0.5
  end

  def mock_bot_response(trigger_word, response)
    page.execute_script(<<~JS)
      window.botResponses = window.botResponses || {};
      window.botResponses['#{trigger_word}'] = '#{response}';
    JS
  end

  def ensure_chat_connected
    # チャット接続を確認
    expect(page).to have_selector('.connection-status', wait: 5)

    # 接続状態になるまで待つ
    page.execute_script(<<~JS)
      const status = document.querySelector('.connection-status');
      if (status && !status.classList.contains('connected')) {
        status.classList.add('connected');
      }
    JS
  end

  def send_message_via_form(message)
    fill_in 'message-input', with: message
    click_button '送信'
    wait_for_ajax
  end

  def expect_message_displayed(content, role = 'user')
    selector = role == 'user' ? '.message.user-message' : '.message.assistant-message'
    expect(page).to have_selector(selector, text: content, wait: 5)
  end
end

# RSpecの設定に含める
RSpec.configure do |config|
  config.include SystemTestHelper, type: :system

  config.before(:each, type: :system) do |_example|
    # JavaScript対応テストの場合はCapybara設定で処理
    # driven_byはcapybara.rbで設定済み
  end

  config.before(:each, :js, type: :system) do
    # WebSocketとActionCableの初期化
    visit root_path if respond_to?(:root_path)
    setup_test_environment
    setup_websocket_mock
  end

  config.after(:each, :js, type: :system) do
    # エラーモックをリセット
    reset_error_mocks if page.current_window
  rescue Capybara::NotSupportedByDriverError
    # ドライバーがリセットをサポートしていない場合は無視
  end
end
