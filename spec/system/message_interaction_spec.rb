# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Message Interaction', :js, type: :system do
  let(:user) { create(:user, name: 'Test User') }
  let!(:conversation) { create(:conversation, user: user) }

  before do
    allow_any_instance_of(ApplicationController).to receive(:current_user).and_return(user)
    allow_any_instance_of(ApplicationController).to receive(:authenticate_user!).and_return(true)
  end

  describe 'メッセージの送信' do
    before do
      visit chat_path(conversation_id: conversation.id)
    end

    it 'テキストメッセージを送信できる' do
      fill_in 'message-input', with: 'こんにちは、テストメッセージです'
      click_button '送信'

      expect(page).to have_content('こんにちは、テストメッセージです')
      expect(page).to have_selector('.message.user-message')

      # データベースに保存されている
      expect(conversation.messages.last.content).to eq('こんにちは、テストメッセージです')
      expect(conversation.messages.last.role).to eq('user')
    end

    it '空のメッセージは送信できない' do
      fill_in 'message-input', with: ''
      click_button '送信'

      expect(page).to have_content('メッセージを入力してください')
      expect(conversation.messages.count).to eq(0)
    end

    it 'Enterキーでメッセージを送信できる' do
      fill_in 'message-input', with: 'Enterキーテスト'
      find('#message-input').send_keys(:enter)

      expect(page).to have_content('Enterキーテスト')
      expect(conversation.messages.last.content).to eq('Enterキーテスト')
    end

    it 'Shift+Enterで改行できる' do
      fill_in 'message-input', with: '改行'
      find('#message-input').send_keys(%i[shift enter])
      find('#message-input').send_keys('テスト')
      click_button '送信'

      expect(page).to have_content("改行\nテスト")
    end

    it '送信後に入力フィールドがクリアされる' do
      fill_in 'message-input', with: 'テストメッセージ'
      click_button '送信'

      expect(find('#message-input').value).to eq('')
    end

    it '連続してメッセージを送信できる' do
      fill_in 'message-input', with: '最初のメッセージ'
      click_button '送信'

      fill_in 'message-input', with: '二番目のメッセージ'
      click_button '送信'

      expect(page).to have_content('最初のメッセージ')
      expect(page).to have_content('二番目のメッセージ')
      expect(conversation.messages.count).to eq(2)
    end
  end

  describe 'メッセージの表示' do
    let!(:old_message) { create(:message, conversation: conversation, content: '古いメッセージ', created_at: 1.hour.ago) }
    let!(:new_message) { create(:message, conversation: conversation, content: '新しいメッセージ', created_at: 1.minute.ago) }

    before do
      visit chat_path(conversation_id: conversation.id)
    end

    it 'メッセージを時系列順に表示する' do
      messages = all('.message')
      expect(messages.first).to have_content('古いメッセージ')
      expect(messages.last).to have_content('新しいメッセージ')
    end

    it 'メッセージのタイムスタンプを表示する' do
      within('.message', match: :first) do
        expect(page).to have_selector('.timestamp')
      end
    end

    it '長いメッセージを適切に折り返す' do
      long_message = 'あ' * 100
      create(:message, conversation: conversation, content: long_message)

      visit chat_path(conversation_id: conversation.id)

      expect(page).to have_content(long_message)
      expect(page).to have_selector('.message-content')
    end
  end

  describe 'タイピングインジケーター' do
    before do
      visit chat_path(conversation_id: conversation.id)
    end

    it 'タイピング中にインジケーターを表示する' do
      fill_in 'message-input', with: 'タイ'

      # WebSocketでタイピング通知が送信される
      expect(page).to have_selector('#typing-indicator', visible: true)
    end

    it 'タイピングを止めるとインジケーターが消える' do
      fill_in 'message-input', with: 'テスト'
      sleep 2 # タイピング停止タイムアウト待ち

      expect(page).to have_selector('#typing-indicator', visible: false)
    end
  end

  describe 'メッセージのスクロール' do
    before do
      # 大量のメッセージを作成
      30.times do |i|
        create(:message, conversation: conversation, content: "メッセージ #{i + 1}")
      end

      visit chat_path(conversation_id: conversation.id)
    end

    it '新しいメッセージで自動スクロールする' do
      # スクロール位置を確認
      scroll_position = page.evaluate_script('document.getElementById("messages-container").scrollTop')

      fill_in 'message-input', with: '新しいメッセージ'
      click_button '送信'

      sleep 0.5 # スクロールアニメーション待ち
      new_scroll_position = page.evaluate_script('document.getElementById("messages-container").scrollTop')

      expect(new_scroll_position).to be > scroll_position
    end

    it '古いメッセージを読むためにスクロールできる' do
      page.execute_script('document.getElementById("messages-container").scrollTop = 0')

      expect(page).to have_content('メッセージ 1')
    end
  end

  describe 'メッセージの既読機能' do
    let!(:unread_message) { create(:message, conversation: conversation, content: '未読メッセージ', role: 'assistant') }

    before do
      visit chat_path(conversation_id: conversation.id)
    end

    it 'メッセージを表示すると既読になる' do
      expect(page).to have_content('未読メッセージ')

      # メッセージが表示されたら既読マークが付く
      within('.message.assistant-message', match: :first) do
        expect(page).to have_selector('.read-indicator')
      end
    end

    it '既読状態がリアルタイムで更新される' do
      # 別のユーザーが既読にした場合のシミュレーション
      page.execute_script("App.cable.subscriptions.find(s => s.identifier.includes('ChatChannel')).received({type: 'message_read', message_id: #{unread_message.id}, user_id: #{user.id}})")

      expect(page).to have_selector('.read-indicator')
    end
  end

  describe 'メッセージの削除' do
    let!(:deletable_message) { create(:message, conversation: conversation, content: '削除可能メッセージ', role: 'user') }

    before do
      visit chat_path(conversation_id: conversation.id)
    end

    it 'ユーザーのメッセージを削除できる' do
      within('.message.user-message', match: :first) do
        find('.message-options').click
        click_button '削除'
      end

      accept_confirm do
        click_button '削除を確認'
      end

      expect(page).not_to have_content('削除可能メッセージ')
      expect(conversation.messages.find_by(id: deletable_message.id)).to be_nil
    end

    it 'アシスタントのメッセージは削除できない' do
      create(:message, conversation: conversation, content: 'アシスタントメッセージ', role: 'assistant')

      visit chat_path(conversation_id: conversation.id)

      within('.message.assistant-message', match: :first) do
        expect(page).not_to have_selector('.message-options')
      end
    end
  end
end
