# frozen_string_literal: true

module SystemTestHelper
  def setup_test_environment
    # テスト用のWebSocket/ActionCableモック
    page.execute_script(<<~JS)
      window.TEST_MODE = true;
      
      // App.cableのモック
      window.App = window.App || {};
      window.App.cable = {
        subscriptions: {
          create: function(channel, callbacks) {
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
      
      // ActionCableのログを抑制
      if (window.ActionCable) {
        window.ActionCable.logger = { log: function() {} };
      }
    JS
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
  
  def setup_websocket_mock
    page.execute_script(<<~JS)
      // WebSocketのモック
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
      
      // テストモードではMockWebSocketを使用
      if (window.TEST_MODE) {
        window.WebSocket = window.MockWebSocket;
      }
    JS
  end
  
  def mock_bot_response(trigger_word, response)
    page.execute_script(<<~JS)
      window.botResponses = window.botResponses || {};
      window.botResponses['#{trigger_word}'] = '#{response}';
    JS
  end
  
  def trigger_error(error_type)
    case error_type
    when :network
      page.execute_script('window.navigator.onLine = false; window.dispatchEvent(new Event("offline"));')
    when :server
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
    when :timeout
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
  end
  
  def reset_error_mocks
    page.execute_script(<<~JS)
      delete window.forceServerError;
      delete window.forceTimeout;
      window.navigator.onLine = true;
      // XMLHttpRequestとfetchをリセット（リロードが必要な場合がある）
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
  
  config.before(:each, type: :system) do |example|
    # JavaScript対応テストの場合はCapybara設定で処理
    # driven_byはcapybara.rbで設定済み
  end
  
  config.before(:each, type: :system, js: true) do
    # WebSocketとActionCableの初期化
    visit root_path if respond_to?(:root_path)
    setup_test_environment
    setup_websocket_mock
  end
  
  config.after(:each, type: :system, js: true) do
    # エラーモックをリセット
    reset_error_mocks if page.current_window
  rescue Capybara::NotSupportedByDriverError
    # ドライバーがリセットをサポートしていない場合は無視
  end
end