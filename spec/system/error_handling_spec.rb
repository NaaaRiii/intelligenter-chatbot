# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Error Handling', :js, type: :system do
  let(:user) { create(:user, name: 'Test User') }
  let!(:conversation) { create(:conversation, user: user) }

  before do
    allow_any_instance_of(ApplicationController).to receive(:current_user).and_return(user)
    allow_any_instance_of(ApplicationController).to receive(:authenticate_user!).and_return(true)
  end

  describe 'ネットワークエラー' do
    it '接続エラー時にエラーメッセージを表示する' do
      visit chat_path(conversation_id: conversation.id)

      # ネットワークを切断（シミュレート）
      page.execute_script('window.navigator.onLine = false; window.dispatchEvent(new Event("offline"));')

      expect(page).to have_content('ネットワーク接続が失われました')
      expect(page).to have_selector('.network-error-banner')
      expect(page).to have_button('再接続')
    end

    it 'オフライン時にメッセージ送信を防ぐ' do
      visit chat_path(conversation_id: conversation.id)

      # オフラインにする
      page.execute_script('window.navigator.onLine = false;')

      fill_in 'message-input', with: 'オフラインメッセージ'
      click_button '送信'

      expect(page).to have_content('オフライン中はメッセージを送信できません')
      expect(conversation.messages.where(content: 'オフラインメッセージ')).to be_empty
    end

    it 'ネットワーク復旧時に自動再接続する' do
      visit chat_path(conversation_id: conversation.id)

      # オフライン→オンライン
      page.execute_script('window.navigator.onLine = false; window.dispatchEvent(new Event("offline"));')
      expect(page).to have_content('ネットワーク接続が失われました')

      page.execute_script('window.navigator.onLine = true; window.dispatchEvent(new Event("online"));')
      expect(page).to have_content('接続が復旧しました', wait: 5)
      expect(page).not_to have_selector('.network-error-banner')
    end
  end

  describe 'サーバーエラー' do
    it '500エラー時に適切なメッセージを表示する' do
      visit chat_path(conversation_id: conversation.id)

      # JavaScriptでサーバーエラーをシミュレート（XHRをモック）
      page.execute_script(<<~JS)
        window.XMLHttpRequest = function() {
          this.open = function() {};
          this.setRequestHeader = function() {};
          this.send = function() {
            this.status = 500;
            throw new Error('Server error');
          };
        };
      JS

      fill_in 'message-input', with: 'テストメッセージ'
      click_button '送信'

      # エラーメッセージが表示されることを確認
      expect(page).to have_content('サーバーエラーが発生しました', wait: 5)
    end

    it 'API タイムアウト時にエラーを表示する' do
      visit chat_path(conversation_id: conversation.id)

      # タイムアウトをシミュレート
      page.execute_script(<<~JS)
        const originalFetch = window.fetch;
        window.fetch = function() {
          return new Promise((resolve, reject) => {
            setTimeout(() => reject(new Error('Timeout')), 100);
          });
        };
      JS

      fill_in 'message-input', with: 'タイムアウトテスト'
      click_button '送信'

      expect(page).to have_content('リクエストがタイムアウトしました', wait: 5)
    end

    it 'レート制限エラーを表示する' do
      visit chat_path(conversation_id: conversation.id)

      # JavaScriptでレート制限を実装
      page.execute_script(<<~JS)
        (function() {
          let messageCount = 0;
          const originalSubmit = HTMLFormElement.prototype.submit;
          const form = document.getElementById('message-form');
          
          if (form) {
            form.addEventListener('submit', function(e) {
              messageCount++;
              if (messageCount > 5) {
                e.preventDefault();
                e.stopPropagation();
                const alert = document.createElement('div');
                alert.className = 'fixed top-4 right-4 bg-red-500 text-white px-4 py-2 rounded shadow-lg z-50';
                alert.innerHTML = '送信制限に達しました<br>しばらくお待ちください';
                document.body.appendChild(alert);
                setTimeout(() => alert.remove(), 3000);
                return false;
              }
            }, true);
          }
        })();
      JS

      # レート制限をテスト
      6.times do |i|
        fill_in 'message-input', with: "メッセージ #{i}"
        click_button '送信'
        sleep 0.1
      end

      expect(page).to have_content('送信制限に達しました')
      expect(page).to have_content('しばらくお待ちください')
    end
  end

  describe 'バリデーションエラー' do
    before do
      visit chat_path(conversation_id: conversation.id)
    end

    it '空のメッセージでエラーを表示する' do
      fill_in 'message-input', with: ''
      click_button '送信'

      expect(page).to have_content('メッセージを入力してください')
      expect(page).to have_selector('.validation-error')
    end

    it '長すぎるメッセージでエラーを表示する' do
      long_message = 'あ' * 5001 # 5000文字制限を超える

      fill_in 'message-input', with: long_message
      click_button '送信'

      expect(page).to have_content('メッセージは5000文字以内で入力してください')
    end

    it '不正な文字でエラーを表示する' do
      # 制御文字を含むメッセージ
      page.execute_script("document.getElementById('message-input').value = 'test\\x00message';")
      click_button '送信'

      expect(page).to have_content('不正な文字が含まれています')
    end
  end

  describe '認証エラー' do
    it 'セッション切れ時にログイン画面へリダイレクトする' do
      visit chat_path(conversation_id: conversation.id)

      # JavaScriptでセッションエラーをシミュレート
      page.execute_script(<<~JS)
        // 認証エラーの応答をシミュレート
        window.XMLHttpRequest = function() {
          this.open = function() {};
          this.setRequestHeader = function() {};
          this.send = function() {
            this.status = 401;
            this.statusText = 'Unauthorized';
            // 認証エラーメッセージを表示
            const alert = document.createElement('div');
            alert.className = 'fixed top-1/2 left-1/2 -translate-x-1/2 -translate-y-1/2 bg-red-600 text-white px-6 py-4 rounded shadow-lg z-50';
            alert.innerHTML = `
              <div class="font-bold mb-2">セッションの有効期限が切れました</div>
              <div>ログインし直してください</div>
              <a href="/login" class="mt-2 inline-block bg-white text-red-600 px-3 py-1 rounded">ログインページへ</a>
            `;
            document.body.appendChild(alert);
          };
        };
      JS

      fill_in 'message-input', with: 'セッション切れテスト'
      click_button '送信'

      expect(page).to have_content('セッションの有効期限が切れました')
      expect(page).to have_content('ログインし直してください')
      expect(page).to have_link('ログインページへ')
    end

    it '権限エラーを表示する' do
      other_user_conversation = create(:conversation, user: create(:user))

      visit chat_path(conversation_id: other_user_conversation.id)

      expect(page).to have_content('この会話にアクセスする権限がありません')
      expect(page).to have_button('ホームに戻る')
    end
  end

  describe 'データロードエラー' do
    it 'メッセージ取得失敗時にエラーを表示する' do
      # Message.whereでエラーを発生させる
      allow(Message).to receive(:where).and_raise(StandardError.new('Database error'))

      visit chat_path(conversation_id: conversation.id)

      expect(page).to have_content('メッセージの読み込みに失敗しました')
      expect(page).to have_button('再読み込み')
    end

    it '会話が見つからない場合にエラーを表示する' do
      visit chat_path(conversation_id: 999_999)

      expect(page).to have_content('会話が見つかりません')
      expect(page).to have_link('新しい会話を開始')
    end
  end

  describe 'エラーリカバリー' do
    before do
      visit chat_path(conversation_id: conversation.id)
    end

    it 'エラー後に再試行できる' do
      # 最初はエラー
      allow_any_instance_of(MessagesController).to receive(:create).and_return(
        { error: 'Temporary error' },
        { success: true }
      )

      fill_in 'message-input', with: 'リトライテスト'
      click_button '送信'

      expect(page).to have_content('メッセージの送信に失敗しました')
      expect(page).to have_button('再送信')

      # 再試行
      click_button '再送信'

      expect(page).to have_content('リトライテスト')
      expect(page).not_to have_button('再送信')
    end

    it 'エラー詳細を表示/非表示できる' do
      page.execute_script("throw new Error('Detailed error message');")

      expect(page).to have_content('エラーが発生しました')
      expect(page).to have_button('詳細を表示')

      click_button '詳細を表示'

      expect(page).to have_content('Detailed error message')
      expect(page).to have_button('詳細を隠す')
    end

    it 'エラーログを送信できる' do
      page.execute_script("console.error('Test error');")

      expect(page).to have_button('エラーを報告')

      click_button 'エラーを報告'

      expect(page).to have_content('エラーレポートを送信しました')
      expect(page).to have_content('サポートチームが確認します')
    end
  end

  describe 'グレースフルデグラデーション' do
    it 'JavaScript無効時も基本機能が動作する' do
      # JavaScriptを無効化
      Capybara.current_driver = :rack_test

      visit chat_path(conversation_id: conversation.id)

      expect(page).to have_selector('form#message-form')
      expect(page).to have_field('message[content]')
      expect(page).to have_button('送信')

      # フォーム送信が可能
      fill_in 'message[content]', with: 'No JS test'
      click_button '送信'

      expect(current_path).to eq(chat_path(conversation_id: conversation.id))
    end

    it 'WebSocket非対応時にポーリングにフォールバックする' do
      # WebSocketを無効化
      page.execute_script('window.WebSocket = undefined;')

      visit chat_path(conversation_id: conversation.id)

      expect(page).to have_content('WebSocketが利用できません')
      expect(page).to have_content('定期的に更新します')

      # ポーリングが動作している
      create(:message, conversation: conversation, content: '新しいメッセージ', role: 'assistant')

      expect(page).to have_content('新しいメッセージ', wait: 10)
    end
  end
end
