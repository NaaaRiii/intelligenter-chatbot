# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Chat Interface', type: :system do
  let(:user) { create(:user, name: 'Test User', email: 'test@example.com') }

  before do
    # ユーザーをセッションに設定
    allow_any_instance_of(ApplicationController).to receive(:current_user).and_return(user)
    allow_any_instance_of(ApplicationController).to receive(:authenticate_user!).and_return(true)
  end

  describe 'チャット画面の表示' do
    it '新しいチャット画面を表示する' do
      visit chat_path

      expect(page).to have_content('チャット')
      expect(page).to have_selector('#chat-container')
      expect(page).to have_selector('#message-input')
      expect(page).to have_button('送信')
    end

    it 'ユーザー情報を表示する' do
      visit chat_path

      expect(page).to have_content('Test User')
      expect(page).to have_content('オンライン')
    end

    it '新しい会話を作成する' do
      expect do
        visit chat_path
      end.to change(Conversation, :count).by(1)

      conversation = Conversation.last
      expect(conversation.user).to eq(user)
      expect(conversation).to be_active
    end
  end

  describe '既存の会話を開く' do
    let!(:conversation) { create(:conversation, user: user) }
    let!(:messages) do
      [
        create(:message, conversation: conversation, content: 'こんにちは', role: 'user'),
        create(:message, conversation: conversation, content: 'いらっしゃいませ', role: 'assistant')
      ]
    end

    it '既存の会話とメッセージを表示する' do
      visit chat_path(conversation_id: conversation.id)

      expect(page).to have_content('こんにちは')
      expect(page).to have_content('いらっしゃいませ')
      expect(page).to have_selector('.message', count: 2)
    end

    it 'メッセージの送信者を区別して表示する' do
      visit chat_path(conversation_id: conversation.id)

      within('.message.user-message', match: :first) do
        expect(page).to have_content('こんにちは')
        expect(page).to have_content('You')
      end

      within('.message.assistant-message', match: :first) do
        expect(page).to have_content('いらっしゃいませ')
        expect(page).to have_content('Bot')
      end
    end
  end

  describe 'UIコンポーネント' do
    before do
      visit chat_path
    end

    it 'ヘッダーを表示する' do
      expect(page).to have_selector('header')
      expect(page).to have_content('Intelligent Chatbot')
    end

    it 'サイドバーを表示する' do
      expect(page).to have_selector('#sidebar')
      expect(page).to have_content('会話履歴')
      expect(page).to have_button('新しいチャット')
    end

    it 'メッセージ入力エリアを表示する' do
      expect(page).to have_selector('#message-input-container')
      expect(page).to have_field('message-input')
      expect(page).to have_button('送信')
    end

    it 'タイピングインジケーターを表示する', :js do
      # JavaScriptが必要なテスト
      expect(page).to have_selector('#typing-indicator', visible: false)
    end
  end

  describe 'レスポンシブデザイン' do
    it 'モバイルビューで適切に表示される' do
      page.driver.browser.manage.window.resize_to(375, 812) # iPhone X size
      visit chat_path

      expect(page).to have_selector('#chat-container')
      expect(page).to have_selector('#message-input')

      # モバイルではサイドバーが隠れる
      expect(page).to have_selector('#sidebar.hidden-mobile', visible: false)
    end

    it 'タブレットビューで適切に表示される' do
      page.driver.browser.manage.window.resize_to(768, 1024) # iPad size
      visit chat_path

      expect(page).to have_selector('#chat-container')
      expect(page).to have_selector('#sidebar')
    end
  end

  describe 'アクセシビリティ' do
    before do
      visit chat_path
    end

    it '適切なARIA属性を持つ' do
      expect(page).to have_selector('[aria-label="チャットメッセージ"]')
      expect(page).to have_selector('[aria-label="メッセージ入力"]')
      expect(page).to have_selector('[role="main"]')
    end

    it 'キーボードナビゲーションが可能' do
      # Tabキーでフォーカス移動可能
      find('#message-input').send_keys(:tab)
      expect(page).to have_selector('button[type="submit"]:focus')
    end

    it 'スクリーンリーダー用のテキストを含む' do
      expect(page).to have_selector('.sr-only', visible: false)
    end
  end

  describe 'エラー状態の表示' do
    it '接続エラーを表示する' do
      # WebSocket接続を無効化
      allow(ActionCable.server).to receive(:broadcast).and_raise(StandardError.new('Connection failed'))

      visit chat_path

      expect(page).to have_content('接続エラー')
      expect(page).to have_selector('.error-message')
    end

    it 'エラー時に再接続ボタンを表示する' do
      allow(ActionCable.server).to receive(:broadcast).and_raise(StandardError.new('Connection failed'))

      visit chat_path

      expect(page).to have_button('再接続')
    end
  end
end
