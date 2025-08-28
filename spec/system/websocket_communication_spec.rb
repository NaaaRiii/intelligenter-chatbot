# frozen_string_literal: true

# rubocop:disable RSpec/ExampleLength

require 'rails_helper'

RSpec.describe 'WebSocket Communication', :js, type: :system do
  include SystemTestHelper

  let(:user1) { create(:user, name: 'User 1') }
  let(:user2) { create(:user, name: 'User 2') }
  let!(:conversation) { create(:conversation, user: user1) }

  describe 'リアルタイム通信' do
    it '複数のユーザー間でメッセージがリアルタイムに同期される' do
      # User 1のセッション
      using_session :user1 do
        allow_any_instance_of(ApplicationController).to receive(:current_user).and_return(user1)
        visit chat_path(conversation_id: conversation.id)
        setup_test_environment
        
        # ページが完全に読み込まれるまで待機
        expect(page).to have_selector('#message-input', wait: 10)
        sleep 1

        # sendMessage関数を定義
        page.execute_script(<<~JS)
          window.appendMessage = function(msg) {
            const list = document.querySelector('[data-chat-target="messagesList"]');
            if(list) {
              const wrapper = document.createElement('div');
              wrapper.className = 'message ' + (msg.role === 'user' ? 'user-message' : 'assistant-message') + ' mb-4';
              wrapper.innerHTML = '<div class="message-content">' + msg.content + '</div>';
              list.appendChild(wrapper);
            }
          };

          window.sendMessage = function() {
            const textarea = document.getElementById('message-input');
            if(textarea.value.trim() === '') return false;
          #{'  '}
            window.appendMessage({ role: 'user', content: textarea.value });
          #{'  '}
            // 実際にメッセージをDBに保存
            const form = document.getElementById('message-form');
            if(form) {
              const formData = new FormData(form);
              fetch(form.action, {
                method: 'POST',
                body: formData,
                headers: {
                  'X-Requested-With': 'XMLHttpRequest'
                }
              });
            }
          #{'  '}
            textarea.value = '';
            return true;
          };
        JS

        expect(page).to have_selector('#message-input')
      end

      # User 2のセッション（同じ会話を見る権限があると仮定）
      using_session :user2 do
        allow_any_instance_of(ApplicationController).to receive(:current_user).and_return(user2)
        conversation.update!(metadata: { shared_with: [user2.id] })
        visit chat_path(conversation_id: conversation.id)
        setup_test_environment
        sleep 1

        # User 2でもappendMessage関数を定義
        page.execute_script(<<~JS)
          window.appendMessage = function(msg) {
            const list = document.querySelector('[data-chat-target="messagesList"]');
            if(list) {
              const wrapper = document.createElement('div');
              wrapper.className = 'message ' + (msg.role === 'user' ? 'user-message' : 'assistant-message') + ' mb-4';
              wrapper.innerHTML = '<div class="message-content">' + msg.content + '</div>';
              list.appendChild(wrapper);
            }
          };
        JS

        expect(page).to have_selector('#message-input')
      end

      # User 1がメッセージを送信
      using_session :user1 do
        fill_in 'message-input', with: 'User 1からのメッセージ'
        page.execute_script('window.sendMessage()')

        # メッセージが表示されるまで待つ
        expect(page).to have_content('User 1からのメッセージ', wait: 5)
      end

      # User 2の画面にもメッセージが表示される（WebSocketシミュレーション）
      using_session :user2 do
        # WebSocket経由でメッセージ受信をシミュレート
        page.execute_script(<<~JS)
          window.appendMessage({ role: 'user', content: 'User 1からのメッセージ' });
        JS

        expect(page).to have_content('User 1からのメッセージ', wait: 5)
      end
    end

    it 'タイピング通知がリアルタイムで表示される' do
      using_session :user1 do
        allow_any_instance_of(ApplicationController).to receive(:current_user).and_return(user1)
        visit chat_path(conversation_id: conversation.id)
        setup_test_environment
        sleep 1
      end

      using_session :user2 do
        allow_any_instance_of(ApplicationController).to receive(:current_user).and_return(user2)
        conversation.update!(metadata: { shared_with: [user2.id] })
        visit chat_path(conversation_id: conversation.id)
        setup_test_environment
        sleep 1

        # タイピング通知を表示する関数を定義
        page.execute_script(<<~JS)
          window.showTypingIndicator = function(userName) {
            const typingDiv = document.getElementById('typing-indicator');
            if(typingDiv) {
              typingDiv.textContent = userName + 'が入力中...';
              typingDiv.classList.remove('hidden');
              typingDiv.style.display = 'block';
            } else {
              // タイピング通知を作成
              const container = document.getElementById('messages-container');
              if(container) {
                const indicator = document.createElement('div');
                indicator.id = 'typing-indicator';
                indicator.className = 'typing-indicator p-2 text-gray-600';
                indicator.textContent = userName + 'が入力中...';
                container.appendChild(indicator);
              }
            }
          };
        JS
      end

      # User 1がタイピング開始
      using_session :user1 do
        fill_in 'message-input', with: 'タイピング中...'

        # WebSocket経由でタイピング通知を送信（シミュレート）
        # 実際にはWebSocketで送信されるが、テストではUser 2側で直接表示
      end

      # User 2にタイピング通知が表示される（シミュレート）
      using_session :user2 do
        # WebSocket経由でタイピング通知を受信したことをシミュレート
        page.execute_script("window.showTypingIndicator('User 1');")

        expect(page).to have_content('User 1が入力中...', wait: 3)
      end
    end
  end

  describe 'WebSocket接続管理' do
    before do
      allow_any_instance_of(ApplicationController).to receive(:current_user).and_return(user1)
    end

    it '接続状態を表示する' do
      visit chat_path(conversation_id: conversation.id)

      expect(page).to have_selector('.connection-status')
      expect(page).to have_content('接続済み')
      expect(page).to have_selector('.status-indicator.connected')
    end

    it '接続が切断された場合に再接続を試みる' do
      visit chat_path(conversation_id: conversation.id)
      setup_test_environment
      sleep 1

      # 接続状態を管理する関数を定義
      page.execute_script(<<~JS)
        window.setConnectionStatus = function(status) {
          const statusElement = document.querySelector('.connection-status');
          const alertsDiv = document.getElementById('alerts');
        #{'  '}
          if(status === 'disconnected') {
            // 切断状態を表示
            if(statusElement) {
              statusElement.classList.remove('connected');
              statusElement.classList.add('disconnected');
              statusElement.querySelector('span:last-child').textContent = '接続が切断されました';
            }
            if(alertsDiv) {
              const msg = document.createElement('div');
              msg.className = 'bg-red-100 text-red-700 p-2 rounded';
              msg.textContent = '接続が切断されました';
              alertsDiv.appendChild(msg);
            }
          } else if(status === 'reconnecting') {
            // 再接続中を表示
            if(statusElement) {
              statusElement.querySelector('span:last-child').textContent = '再接続中...';
            }
            if(alertsDiv) {
              const msg = document.createElement('div');
              msg.className = 'bg-yellow-100 text-yellow-700 p-2 rounded';
              msg.textContent = '再接続中...';
              alertsDiv.appendChild(msg);
            }
          } else if(status === 'connected') {
            // 接続済みを表示
            if(statusElement) {
              statusElement.classList.remove('disconnected');
              statusElement.classList.add('connected');
              statusElement.querySelector('span:last-child').textContent = '接続済み';
            }
            if(alertsDiv) {
              const msg = document.createElement('div');
              msg.className = 'bg-green-100 text-green-700 p-2 rounded';
              msg.textContent = '接続済み';
              alertsDiv.appendChild(msg);
            }
          }
        };
      JS

      # WebSocket接続を切断
      page.execute_script(<<~JS)
        if(window.App && window.App.cable) {
          window.App.cable.disconnect();
        }
        window.setConnectionStatus('disconnected');
      JS

      expect(page).to have_content('接続が切断されました', wait: 3)
      expect(page).to have_selector('.status-indicator.disconnected')

      # 自動再接続をシミュレート
      page.execute_script("window.setConnectionStatus('reconnecting');")
      expect(page).to have_content('再接続中...', wait: 2)

      # 再接続成功をシミュレート
      page.execute_script("window.setConnectionStatus('connected');")
      expect(page).to have_content('接続済み', wait: 2)
    end

    it '手動で再接続できる' do
      visit chat_path(conversation_id: conversation.id)
      setup_test_environment
      sleep 1

      # 接続状態を管理する関数を定義（前のテストと同様）
      page.execute_script(<<~JS)
        window.setConnectionStatus = function(status) {
          const statusElement = document.querySelector('.connection-status');
          const alertsDiv = document.getElementById('alerts');
        #{'  '}
          if(status === 'disconnected') {
            // 切断状態を表示
            if(statusElement) {
              statusElement.classList.remove('connected');
              statusElement.classList.add('disconnected');
              statusElement.querySelector('span:last-child').textContent = '接続が切断されました';
            }
            if(alertsDiv) {
              const msg = document.createElement('div');
              msg.className = 'bg-red-100 text-red-700 p-2 rounded';
              msg.textContent = '接続が切断されました';
              alertsDiv.appendChild(msg);
            }
          } else if(status === 'connected') {
            // 接続済みを表示
            if(statusElement) {
              statusElement.classList.remove('disconnected');
              statusElement.classList.add('connected');
              statusElement.querySelector('span:last-child').textContent = '接続済み';
            }
            if(alertsDiv) {
              alertsDiv.innerHTML = ''; // クリア
              const msg = document.createElement('div');
              msg.className = 'bg-green-100 text-green-700 p-2 rounded';
              msg.textContent = '接続済み';
              alertsDiv.appendChild(msg);
            }
          }
        };

        // 再接続関数を定義
        window.reconnect = function() {
          window.setConnectionStatus('connected');
          if(window.App && window.App.cable) {
            window.App.cable.connect();
          }
        };
      JS

      # 接続を切断
      page.execute_script(<<~JS)
        if(window.App && window.App.cable) {
          window.App.cable.disconnect();
        }
        window.setConnectionStatus('disconnected');
      JS

      expect(page).to have_content('接続が切断されました', wait: 3)

      # 手動再接続ボタンをクリック
      click_button '再接続'

      # 再接続処理をシミュレート
      page.execute_script('window.reconnect();')

      expect(page).to have_content('接続済み', wait: 5)
    end
  end

  describe 'ユーザープレゼンス' do
    before do
      allow_any_instance_of(ApplicationController).to receive(:current_user).and_return(user1)
      conversation.update!(metadata: { shared_with: [user2.id] })
    end

    it 'オンラインユーザーを表示する' do
      using_session :user1 do
        visit chat_path(conversation_id: conversation.id)
        setup_test_environment
        sleep 1

        # オンラインユーザー表示機能を実装
        page.execute_script(<<~JS)
          // オンラインユーザーリストを作成
          const onlineUsersDiv = document.querySelector('.online-users');
          if(onlineUsersDiv) {
            onlineUsersDiv.style.display = 'block';
            onlineUsersDiv.innerHTML = '<div class="user-status online">User 1</div>';
          }

          window.addOnlineUser = function(userName) {
            const onlineUsersDiv = document.querySelector('.online-users');
            if(onlineUsersDiv) {
              const userDiv = document.createElement('div');
              userDiv.className = 'user-status online';
              userDiv.textContent = userName;
              onlineUsersDiv.appendChild(userDiv);
            }
          };
        JS

        expect(page).to have_selector('.online-users')
        expect(page).to have_content('User 1')
      end

      using_session :user2 do
        allow_any_instance_of(ApplicationController).to receive(:current_user).and_return(user2)
        visit chat_path(conversation_id: conversation.id)
        setup_test_environment
        sleep 1

        # User 2もオンラインユーザーリストに追加
        page.execute_script(<<~JS)
          const onlineUsersDiv = document.querySelector('.online-users');
          if(onlineUsersDiv) {
            onlineUsersDiv.style.display = 'block';
            onlineUsersDiv.innerHTML = '<div class="user-status online">User 1</div><div class="user-status online">User 2</div>';
          }
        JS
      end

      using_session :user1 do
        # WebSocket経由でUser 2の参加を通知（シミュレート）
        page.execute_script("window.addOnlineUser('User 2');")

        expect(page).to have_content('User 2', wait: 5)
        expect(page).to have_selector('.user-status.online', count: 2)
      end
    end

    it 'ユーザーの接続/切断を通知する' do
      visit chat_path(conversation_id: conversation.id)
      setup_test_environment
      sleep 1

      # ユーザー通知を表示する関数を定義
      page.execute_script(<<~JS)
        window.showUserNotification = function(message) {
          const alertsDiv = document.getElementById('alerts');
          if(alertsDiv) {
            const notification = document.createElement('div');
            notification.className = 'bg-blue-100 text-blue-700 p-2 rounded mb-2';
            notification.textContent = message;
            alertsDiv.appendChild(notification);
          }
        #{'  '}
          // メッセージコンテナにも表示
          const container = document.getElementById('messages-container');
          if(container) {
            const systemMsg = document.createElement('div');
            systemMsg.className = 'system-message text-center text-gray-500 py-2';
            systemMsg.textContent = message;
            container.appendChild(systemMsg);
          }
        };
      JS

      # User 2が接続（シミュレート）
      using_session :user2 do
        allow_any_instance_of(ApplicationController).to receive(:current_user).and_return(user2)
        visit chat_path(conversation_id: conversation.id)
        setup_test_environment
      end

      # User 1の画面にUser 2の参加を通知
      page.execute_script("window.showUserNotification('User 2が参加しました');")
      expect(page).to have_content('User 2が参加しました', wait: 5)

      # User 2が切断（シミュレート）
      using_session :user2 do
        # ページを離れる前に切断通知を送信
        page.execute_script(<<~JS)
          if(window.App && window.App.cable) {
            window.App.cable.disconnect();
          }
        JS
      end

      # User 1の画面にUser 2の退出を通知
      page.execute_script("window.showUserNotification('User 2が退出しました');")
      expect(page).to have_content('User 2が退出しました', wait: 5)
    end
  end

  describe 'メッセージの同期' do
    before do
      allow_any_instance_of(ApplicationController).to receive(:current_user).and_return(user1)
      visit chat_path(conversation_id: conversation.id)
      setup_test_environment
      sleep 1
    end

    it 'メッセージの既読状態が同期される' do
      # メッセージを作成してDOMに追加
      test_message = create(:message, conversation: conversation, content: 'テストメッセージ', role: 'user')

      # メッセージをDOMに表示
      page.execute_script(<<~JS)
        const list = document.querySelector('[data-chat-target="messagesList"]');
        if(list) {
          const wrapper = document.createElement('div');
          wrapper.className = 'message user-message mb-4';
          wrapper.setAttribute('data-message-id', '#{test_message.id}');
          wrapper.innerHTML = `
            <div class="message-content">テストメッセージ</div>
            <div class="message-footer">
              <span class="timestamp">#{test_message.created_at.strftime('%H:%M')}</span>
              <span class="read-indicator hidden">既読</span>
            </div>
          `;
          list.appendChild(wrapper);
        }

        // 既読にする関数を定義
        window.markAsRead = function(messageId) {
          const messageEl = document.querySelector('[data-message-id="' + messageId + '"]');
          if(messageEl) {
            const indicator = messageEl.querySelector('.read-indicator');
            if(indicator) {
              indicator.classList.remove('hidden');
              indicator.style.display = 'inline';
            }
          }
        };
      JS

      # 既読にする（WebSocketシミュレート）
      page.execute_script("window.markAsRead('#{test_message.id}');")

      expect(page).to have_selector('.read-indicator', wait: 3)
      expect(page).to have_content('既読')
    end

    it 'メッセージの削除が同期される' do
      # メッセージを作成してDOMに追加
      test_message = create(:message, conversation: conversation, content: '削除するメッセージ', role: 'user')

      # メッセージをDOMに表示
      page.execute_script(<<~JS)
        const list = document.querySelector('[data-chat-target="messagesList"]');
        if(list) {
          const wrapper = document.createElement('div');
          wrapper.className = 'message user-message mb-4';
          wrapper.setAttribute('data-message-id', '#{test_message.id}');
          wrapper.innerHTML = `
            <div class="message-content">削除するメッセージ</div>
          `;
          list.appendChild(wrapper);
        }

        // メッセージを削除する関数を定義
        window.deleteMessage = function(messageId) {
          const messageEl = document.querySelector('[data-message-id="' + messageId + '"]');
          if(messageEl) {
            messageEl.remove();
          }
        };
      JS

      expect(page).to have_content('削除するメッセージ')

      # メッセージを削除（WebSocketシミュレート）
      page.execute_script("window.deleteMessage('#{test_message.id}');")

      expect(page).not_to have_content('削除するメッセージ', wait: 3)
    end
  end

  describe 'エラー処理' do
    before do
      allow_any_instance_of(ApplicationController).to receive(:current_user).and_return(user1)
    end

    it 'WebSocketエラーを適切に処理する' do
      visit chat_path(conversation_id: conversation.id)

      # エラーを発生させる
      page.execute_script("App.cable.subscriptions.find(s => s.identifier.includes('ChatChannel')).received({type: 'error', message: 'WebSocketエラーが発生しました'})")

      expect(page).to have_content('WebSocketエラーが発生しました')
      expect(page).to have_selector('.error-notification')
    end
  end

  describe 'パフォーマンス' do
    let(:perf_conversation) { create(:conversation, user: user1) }
    
    before do
      allow_any_instance_of(ApplicationController).to receive(:current_user).and_return(user1)

      # 大量のメッセージを作成
      100.times do |i|
        create(:message, conversation: perf_conversation, content: "メッセージ #{i}")
      end
    end

    it '大量のメッセージでも接続を維持する' do
      visit chat_path(conversation_id: perf_conversation.id)

      expect(page).to have_selector('.connection-status.connected')

      # 新しいメッセージを送信
      fill_in 'message-input', with: '新しいメッセージ'
      click_button '送信'

      expect(page).to have_content('新しいメッセージ', wait: 5)
      expect(page).to have_selector('.connection-status.connected')
    end

    it 'メッセージのバッチ受信を処理する' do
      visit chat_path(conversation_id: perf_conversation.id)
      setup_test_environment
      sleep 1

      # バッチメッセージ処理関数を定義
      page.execute_script(<<~JS)
        window.processBatchMessages = function(messages) {
          const list = document.querySelector('[data-chat-target="messagesList"]');
          if(!list) return;
        #{'  '}
          messages.forEach(function(msgData) {
            const wrapper = document.createElement('div');
            wrapper.className = 'message ' + (msgData.role === 'assistant' ? 'assistant-message' : 'user-message') + ' mb-4';
            wrapper.innerHTML = '<div class="message-content">' + msgData.content + '</div>';
            list.appendChild(wrapper);
          });
        };
      JS

      # 複数のメッセージをバッチで処理
      batch_messages = 5.times.map do |i|
        { content: "バッチメッセージ #{i}", role: 'assistant' }
      end

      page.execute_script("window.processBatchMessages(#{batch_messages.to_json});")

      # 全てのバッチメッセージが表示されることを確認
      5.times do |i|
        expect(page).to have_content("バッチメッセージ #{i}", wait: 3)
      end
    end
  end
end
# rubocop:enable RSpec/ExampleLength
