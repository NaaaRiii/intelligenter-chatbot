# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'リアルタイムAI分析のE2Eテスト', type: :system do
  let(:user) { create(:user) }
  let(:conversation) { create(:conversation, user: user) }

  before do
    # ActionCableのモック設定
    allow(ActionCable.server).to receive(:broadcast)
    
    # Sidekiqを同期モードに
    Sidekiq::Testing.inline!
  end

  after do
    Sidekiq::Testing.fake!
  end

  describe 'WebSocketを通じたリアルタイム分析' do
    it '新しいメッセージが追加されるとリアルタイムで分析が更新される' do
      visit conversation_path(conversation)
      
      # WebSocket接続を確立
      expect(page).to have_css('[data-channel="conversation"]', wait: 5)
      
      # 別のブラウザセッションをシミュレート
      in_browser(:other) do
        visit conversation_path(conversation)
        
        within '#chat-interface' do
          fill_in 'message_content', with: 'パフォーマンスが悪い'
          click_button '送信'
        end
      end
      
      # 元のセッションでリアルタイム更新を確認
      within '.conversation-analysis' do
        expect(page).to have_content('分析を更新中...', wait: 2)
        expect(page).to have_content('新しい分析結果', wait: 5)
      end
    end
  end

  describe 'プログレッシブ分析更新' do
    it '長い会話の分析が段階的に表示される' do
      # 長い会話履歴を作成
      20.times do |i|
        create(:message, 
               conversation: conversation, 
               role: i.even? ? 'user' : 'assistant',
               content: "メッセージ #{i + 1}")
      end
      
      visit conversation_path(conversation)
      
      # プログレッシブ分析を開始
      click_button '詳細分析'
      
      # 段階的な更新を確認
      within '.analysis-progress-details' do
        expect(page).to have_content('メッセージ分析中: 1/20', wait: 2)
        expect(page).to have_content('メッセージ分析中: 10/20', wait: 5)
        expect(page).to have_content('メッセージ分析中: 20/20', wait: 8)
        expect(page).to have_content('分析結果を集計中...', wait: 9)
      end
      
      # 最終結果が表示される
      expect(page).to have_css('.complete-analysis-results', wait: 10)
    end
  end

  describe 'ダッシュボードでのリアルタイム集計' do
    before do
      # 複数の会話を作成
      @conversations = create_list(:conversation, 3, user: user)
      @conversations.each do |conv|
        create_list(:message, 2, conversation: conv)
      end
    end

    it 'ダッシュボードの統計がリアルタイムで更新される' do
      visit dashboard_path
      
      # 初期状態の統計を確認
      within '#statistics' do
        expect(page).to have_content('未分析: 3')
        expect(page).to have_content('分析済み: 0')
      end
      
      # バックグラウンドで分析を実行
      @conversations.first.messages.create!(
        role: 'user',
        content: '緊急の問題が発生'
      )
      
      # 統計がリアルタイムで更新される
      within '#statistics' do
        expect(page).to have_content('分析中: 1', wait: 3)
        expect(page).to have_content('未分析: 2')
        expect(page).to have_content('分析済み: 1', wait: 10)
      end
    end

    it 'エスカレーション通知がダッシュボードにリアルタイム表示される' do
      visit dashboard_path
      
      # エスカレーションカウンターの初期値
      within '#escalation-counter' do
        expect(page).to have_content('0')
      end
      
      # 別の場所でエスカレーションが発生
      analysis = create(:analysis,
                       conversation: @conversations.first,
                       priority_level: 'high',
                       escalation_required: true)
      
      # ActionCableでエスカレーション通知を送信
      ActionCable.server.broadcast(
        'dashboard_channel',
        {
          type: 'new_escalation',
          conversation_id: @conversations.first.id,
          priority: 'high'
        }
      )
      
      # ダッシュボードに通知が表示される
      within '#escalation-counter' do
        expect(page).to have_content('1', wait: 3)
      end
      
      # アラートポップアップが表示される
      expect(page).to have_css('.escalation-popup', wait: 2)
      within '.escalation-popup' do
        expect(page).to have_content('新しいエスカレーション')
        expect(page).to have_content('優先度: high')
        click_link '詳細を見る'
      end
      
      # 会話詳細ページに遷移
      expect(current_path).to eq(conversation_path(@conversations.first))
    end
  end

  describe 'バッチ分析の進捗表示' do
    it 'バッチ分析の進捗がプログレスバーで表示される' do
      conversations = create_list(:conversation, 10, user: user)
      
      visit dashboard_path
      
      # バッチ分析を開始
      click_button '全会話を一括分析'
      
      # 確認ダイアログ
      within '.modal' do
        expect(page).to have_content('10件の会話を分析します')
        click_button '開始'
      end
      
      # プログレスバーが表示される
      within '#batch-progress' do
        expect(page).to have_css('.progress-bar', wait: 2)
        
        # プログレスが更新される
        expect(page).to have_content('0/10', wait: 1)
        expect(page).to have_content('5/10', wait: 5)
        expect(page).to have_content('10/10', wait: 10)
      end
      
      # 完了メッセージ
      expect(page).to have_content('バッチ分析が完了しました')
      expect(page).to have_css('.success-notification')
    end
  end

  describe 'エラー発生時のリアルタイム通知' do
    it 'API制限エラーがリアルタイムで通知される' do
      # API制限をシミュレート
      allow_any_instance_of(ClaudeApiService)
        .to receive(:analyze_conversation)
        .and_raise(ClaudeApiService::RateLimitError, 'Rate limit exceeded')
      
      visit conversation_path(conversation)
      
      click_button '会話を分析'
      
      # エラー通知がリアルタイムで表示される
      expect(page).to have_css('.error-toast', wait: 3)
      within '.error-toast' do
        expect(page).to have_content('API制限に達しました')
        expect(page).to have_content('1時間後に再試行')
      end
      
      # リトライボタンが無効化される
      expect(page).to have_button('会話を分析', disabled: true)
      
      # カウントダウンタイマーが表示される
      within '.retry-timer' do
        expect(page).to have_content('次回実行可能まで: 59:')
      end
    end
  end
end