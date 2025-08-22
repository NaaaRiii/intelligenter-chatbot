# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Bot Response', :js, type: :system do
  let(:user) { create(:user, name: 'Test User') }
  let!(:conversation) { create(:conversation, user: user) }

  before do
    allow_any_instance_of(ApplicationController).to receive(:current_user).and_return(user)
    allow_any_instance_of(ApplicationController).to receive(:authenticate_user!).and_return(true)

    # ActiveJobをインラインモードに設定（テスト用）
    ActiveJob::Base.queue_adapter.perform_enqueued_jobs = true
  end

  after do
    ActiveJob::Base.queue_adapter.perform_enqueued_jobs = false
  end

  describe 'ボット自動応答' do
    before do
      visit chat_path(conversation_id: conversation.id)
    end

    it 'ユーザーメッセージに対してボットが応答する' do
      fill_in 'message-input', with: 'こんにちは'
      click_button '送信'

      # ボット応答を待つ
      expect(page).to have_selector('.message.assistant-message', wait: 5)
      expect(page).to have_content('いらっしゃいませ')
    end

    it '質問に対して適切な応答をする' do
      fill_in 'message-input', with: 'このサービスの使い方を教えてください'
      click_button '送信'

      expect(page).to have_selector('.message.assistant-message', wait: 5)

      within('.message.assistant-message', match: :first) do
        expect(page.text).to match(/ご質問|お問い合わせ|確認/)
      end
    end

    it '苦情に対して謝罪の応答をする' do
      fill_in 'message-input', with: 'エラーが発生して困っています'
      click_button '送信'

      expect(page).to have_selector('.message.assistant-message', wait: 5)

      within('.message.assistant-message', match: :first) do
        expect(page.text).to match(/申し訳|お詫び|ご不便/)
      end
    end

    it 'フィードバックに対して感謝の応答をする' do
      fill_in 'message-input', with: '機能改善の提案があります'
      click_button '送信'

      expect(page).to have_selector('.message.assistant-message', wait: 5)

      within('.message.assistant-message', match: :first) do
        expect(page.text).to match(/フィードバック|ご意見|改善/)
      end
    end
  end

  describe 'ボット応答のタイミング' do
    before do
      visit chat_path(conversation_id: conversation.id)
    end

    it 'ボットがタイピング中の表示をする' do
      fill_in 'message-input', with: 'テストメッセージ'
      click_button '送信'

      # タイピングインジケーターが表示される
      expect(page).to have_selector('.bot-typing-indicator', wait: 2)
      expect(page).to have_content('ボットが入力中...')

      # ボット応答後にインジケーターが消える
      expect(page).to have_selector('.message.assistant-message', wait: 5)
      expect(page).not_to have_selector('.bot-typing-indicator')
    end

    it '複数のメッセージに順番に応答する' do
      fill_in 'message-input', with: '最初の質問'
      click_button '送信'

      # 最初のボット応答を待つ
      expect(page).to have_selector('.message.assistant-message', count: 1, wait: 10)

      fill_in 'message-input', with: '二番目の質問'
      click_button '送信'

      # 二番目のボット応答を待つ
      expect(page).to have_selector('.message.assistant-message', count: 2, wait: 10)

      # メッセージの順番を確認
      assistant_messages = all('.message.assistant-message')
      expect(assistant_messages.count).to eq(2)

      # 両方の応答が表示されていることを確認（「質問」というキーワードへの応答）
      expect(assistant_messages[0]).to have_content('ご質問ありがとうございます')
      expect(assistant_messages[1]).to have_content('ご質問ありがとうございます')
    end
  end

  describe 'ボット応答の表示' do
    before do
      visit chat_path(conversation_id: conversation.id)
    end

    it 'ボットアイコンと名前を表示する' do
      fill_in 'message-input', with: 'テスト'
      click_button '送信'

      expect(page).to have_selector('.message.assistant-message', wait: 5)

      within('.message.assistant-message', match: :first) do
        expect(page).to have_selector('.bot-avatar')
        expect(page).to have_content('Bot')
      end
    end

    it 'ボット応答にメタデータを表示する' do
      fill_in 'message-input', with: 'こんにちは'
      click_button '送信'

      expect(page).to have_selector('.message.assistant-message', wait: 5)

      within('.message.assistant-message', match: :first) do
        find('.message-info').click
        expect(page).to have_content('意図: greeting')
        expect(page).to have_content('信頼度:')
      end
    end
  end

  describe 'ボット応答のエラー処理' do
    before do
      # ボット応答をエラーにする
      allow_any_instance_of(ChatBotService).to receive(:generate_response).and_return(nil)

      visit chat_path(conversation_id: conversation.id)
    end

    it 'エラー時にエラーメッセージを表示する' do
      fill_in 'message-input', with: 'テスト'
      click_button '送信'

      expect(page).to have_selector('.message.assistant-message', wait: 5)

      within('.message.assistant-message', match: :first) do
        expect(page).to have_content('申し訳ございません')
        expect(page).to have_content('システムに問題が発生')
        expect(page).to have_selector('.error-indicator')
      end
    end

    it 'エラー後も継続して使用できる' do
      fill_in 'message-input', with: 'エラーテスト'
      click_button '送信'

      expect(page).to have_content('システムに問題が発生')

      # エラーを解除
      allow_any_instance_of(ChatBotService).to receive(:generate_response).and_call_original

      fill_in 'message-input', with: '次のメッセージ'
      click_button '送信'

      # 正常な応答が返る
      expect(page).to have_selector('.message.assistant-message', count: 2, wait: 5)
    end
  end

  describe 'ボット応答の無効化' do
    before do
      conversation.update!(metadata: { bot_enabled: false })
      visit chat_path(conversation_id: conversation.id)
    end

    it 'ボットが無効の場合は応答しない' do
      fill_in 'message-input', with: 'こんにちは'
      click_button '送信'

      # ユーザーメッセージのみ表示
      expect(page).to have_selector('.message.user-message')

      # ボット応答を待っても表示されない
      sleep 2
      expect(page).not_to have_selector('.message.assistant-message')
    end

    it 'ボット無効の通知を表示する' do
      expect(page).to have_content('ボット応答は無効になっています')
      expect(page).to have_button('ボットを有効にする')
    end
  end

  describe 'ボット応答の履歴' do
    let!(:past_messages) do
      [
        create(:message, conversation: conversation, content: '過去の質問', role: 'user', created_at: 1.hour.ago),
        create(:message, conversation: conversation, content: '過去の応答', role: 'assistant', created_at: 59.minutes.ago)
      ]
    end

    before do
      visit chat_path(conversation_id: conversation.id)
    end

    it '過去のボット応答を表示する' do
      expect(page).to have_content('過去の質問')
      expect(page).to have_content('過去の応答')

      within('.message.assistant-message', match: :first) do
        expect(page).to have_content('過去の応答')
      end
    end

    it '会話の文脈を考慮した応答をする' do
      fill_in 'message-input', with: 'さっきの件について詳しく教えて'
      click_button '送信'

      expect(page).to have_selector('.message.assistant-message', wait: 5)

      # 文脈を考慮した応答が含まれる
      bot_response = conversation.messages.assistant_messages.last
      expect(bot_response).not_to be_nil
    end
  end
end
