# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'WebSocket Communication', :js, type: :system do
  let(:user1) { create(:user, name: 'User 1') }
  let(:user2) { create(:user, name: 'User 2') }
  let!(:conversation) { create(:conversation, user: user1) }

  describe 'リアルタイム通信' do
    it '複数のユーザー間でメッセージがリアルタイムに同期される' do
      # User 1のセッション
      using_session :user1 do
        allow_any_instance_of(ApplicationController).to receive(:current_user).and_return(user1)
        visit chat_path(conversation_id: conversation.id)
        expect(page).to have_content('チャット')
      end

      # User 2のセッション（同じ会話を見る権限があると仮定）
      using_session :user2 do
        allow_any_instance_of(ApplicationController).to receive(:current_user).and_return(user2)
        conversation.update!(metadata: { shared_with: [user2.id] })
        visit chat_path(conversation_id: conversation.id)
        expect(page).to have_content('チャット')
      end

      # User 1がメッセージを送信
      using_session :user1 do
        fill_in 'message-input', with: 'User 1からのメッセージ'
        click_button '送信'
        expect(page).to have_content('User 1からのメッセージ')
      end

      # User 2の画面にもメッセージが表示される
      using_session :user2 do
        expect(page).to have_content('User 1からのメッセージ', wait: 5)
      end
    end

    it 'タイピング通知がリアルタイムで表示される' do
      using_session :user1 do
        allow_any_instance_of(ApplicationController).to receive(:current_user).and_return(user1)
        visit chat_path(conversation_id: conversation.id)
      end

      using_session :user2 do
        allow_any_instance_of(ApplicationController).to receive(:current_user).and_return(user2)
        conversation.update!(metadata: { shared_with: [user2.id] })
        visit chat_path(conversation_id: conversation.id)
      end

      # User 1がタイピング開始
      using_session :user1 do
        fill_in 'message-input', with: 'タイピング中...'
      end

      # User 2にタイピング通知が表示される
      using_session :user2 do
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

      # WebSocket接続を切断
      page.execute_script('App.cable.disconnect()')

      expect(page).to have_content('接続が切断されました', wait: 3)
      expect(page).to have_selector('.status-indicator.disconnected')

      # 自動再接続
      expect(page).to have_content('再接続中...', wait: 5)
      expect(page).to have_content('接続済み', wait: 10)
    end

    it '手動で再接続できる' do
      visit chat_path(conversation_id: conversation.id)

      # 接続を切断
      page.execute_script('App.cable.disconnect()')
      expect(page).to have_content('接続が切断されました', wait: 3)

      # 手動再接続ボタンをクリック
      click_button '再接続'

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
        expect(page).to have_selector('.online-users')
        expect(page).to have_content('User 1')
      end

      using_session :user2 do
        allow_any_instance_of(ApplicationController).to receive(:current_user).and_return(user2)
        visit chat_path(conversation_id: conversation.id)
      end

      using_session :user1 do
        expect(page).to have_content('User 2', wait: 5)
        expect(page).to have_selector('.user-status.online', count: 2)
      end
    end

    it 'ユーザーの接続/切断を通知する' do
      visit chat_path(conversation_id: conversation.id)

      # User 2が接続
      using_session :user2 do
        allow_any_instance_of(ApplicationController).to receive(:current_user).and_return(user2)
        visit chat_path(conversation_id: conversation.id)
      end

      expect(page).to have_content('User 2が参加しました', wait: 5)

      # User 2が切断
      using_session :user2 do
        page.driver.quit
      end

      expect(page).to have_content('User 2が退出しました', wait: 5)
    end
  end

  describe 'メッセージの同期' do
    before do
      allow_any_instance_of(ApplicationController).to receive(:current_user).and_return(user1)
      visit chat_path(conversation_id: conversation.id)
    end

    it 'メッセージの既読状態が同期される' do
      # メッセージを送信
      fill_in 'message-input', with: 'テストメッセージ'
      click_button '送信'

      message = conversation.messages.last

      # 既読にする
      page.execute_script("App.cable.subscriptions.find(s => s.identifier.includes('ChatChannel')).perform('mark_as_read', {message_id: #{message.id}})")

      expect(page).to have_selector('.read-indicator', wait: 3)
    end

    it 'メッセージの削除が同期される' do
      # メッセージを送信
      fill_in 'message-input', with: '削除するメッセージ'
      click_button '送信'

      expect(page).to have_content('削除するメッセージ')

      message = conversation.messages.last

      # メッセージを削除（WebSocket経由）
      page.execute_script("App.cable.subscriptions.find(s => s.identifier.includes('ChatChannel')).received({type: 'message_deleted', message_id: #{message.id}})")

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

    it '認証エラーで接続を拒否する' do
      # 認証なしでアクセス
      allow_any_instance_of(ApplicationController).to receive(:current_user).and_return(nil)

      visit chat_path(conversation_id: conversation.id)

      expect(page).to have_content('認証が必要です')
      expect(page).not_to have_selector('.connection-status.connected')
    end
  end

  describe 'パフォーマンス' do
    before do
      allow_any_instance_of(ApplicationController).to receive(:current_user).and_return(user1)

      # 大量のメッセージを作成
      100.times do |i|
        create(:message, conversation: conversation, content: "メッセージ #{i}")
      end
    end

    it '大量のメッセージでも接続を維持する' do
      visit chat_path(conversation_id: conversation.id)

      expect(page).to have_selector('.connection-status.connected')

      # 新しいメッセージを送信
      fill_in 'message-input', with: '新しいメッセージ'
      click_button '送信'

      expect(page).to have_content('新しいメッセージ', wait: 5)
      expect(page).to have_selector('.connection-status.connected')
    end

    it 'メッセージのバッチ受信を処理する' do
      visit chat_path(conversation_id: conversation.id)

      # 複数のメッセージを一度に受信
      messages = 5.times.map do |i|
        { type: 'new_message', message: { content: "バッチメッセージ #{i}", role: 'assistant' } }
      end

      page.execute_script("App.cable.subscriptions.find(s => s.identifier.includes('ChatChannel')).received({type: 'batch_messages', messages: #{messages.to_json}})")

      5.times do |i|
        expect(page).to have_content("バッチメッセージ #{i}", wait: 3)
      end
    end
  end
end
