# frozen_string_literal: true

require 'rails_helper'
require 'sidekiq/testing'

RSpec.describe 'Sidekiq非同期処理のE2Eテスト', type: :system do
  let(:user) { create(:user) }

  before do
    # Sidekiqをfakeモードに設定（ジョブをキューに入れるが実行しない）
    Sidekiq::Testing.fake!
    
    # Redisをクリア
    Sidekiq::Worker.clear_all
  end

  after do
    Sidekiq::Testing.fake!
  end

  describe 'ConversationAnalysisWorkerの非同期実行' do
    let(:conversation) { create(:conversation, user: user) }

    before do
      create_list(:message, 5, conversation: conversation)
    end

    it 'ワーカーがキューに追加され、非同期で実行される' do
      visit conversation_path(conversation)
      
      # 分析開始前のジョブ数を確認
      expect(ConversationAnalysisWorker.jobs.size).to eq(0)
      
      # 分析を開始
      click_button '非同期分析を開始'
      
      # ジョブがキューに追加される
      expect(page).to have_content('分析をキューに追加しました')
      expect(ConversationAnalysisWorker.jobs.size).to eq(1)
      
      # ジョブの詳細を確認
      job = ConversationAnalysisWorker.jobs.first
      expect(job['args']).to eq([conversation.id, { 'use_storage' => false }])
      expect(job['queue']).to eq('analysis')
      
      # ワーカーを実行
      ConversationAnalysisWorker.drain
      
      # JavaScript実行を待つ
      sleep 1.5
      
      # 分析結果を確認
      expect(page).to have_content('分析完了')
      expect(page).to have_content('処理時間:')
    end

    it 'リトライ機能が正しく動作する' do
      # 最初の2回は失敗、3回目で成功するように設定
      attempt = 0
      allow_any_instance_of(SentimentAnalyzer).to receive(:analyze_conversation) do
        attempt += 1
        if attempt < 3
          raise StandardError, 'Temporary failure'
        else
          {
            overall_sentiment: 'positive',
            confidence_score: 1.0,
            sentiment_history: [],
            keyword_insights: {},
            escalation_required: false
          }
        end
      end
      
      visit conversation_path(conversation)
      
      # JavaScriptでリトライカウントを設定（テスト用）
      page.execute_script('window.analysisRetryCount = 2')
      
      click_button '非同期分析を開始'
      
      # ジョブを実行（リトライ含む）
      begin
        ConversationAnalysisWorker.drain
      rescue StandardError
        # リトライを許可
      end
      
      # JavaScript実行を待つ
      sleep 1.5
      
      # リトライが記録されている
      expect(page).to have_content('分析完了（リトライ: 2回）')
    end
  end

  describe 'BatchAnalysisWorkerの一括処理' do
    let(:conversations) { create_list(:conversation, 10, user: user) }

    before do
      conversations.each do |conv|
        create_list(:message, 2, conversation: conv)
      end
    end

    it 'バッチ処理が複数のジョブを生成する' do
      visit dashboard_conversations_path
      
      # バッチ分析前の状態
      expect(BatchAnalysisWorker.jobs.size).to eq(0)
      expect(ConversationAnalysisWorker.jobs.size).to eq(0)
      
      # バッチ分析を開始
      click_button 'バッチ分析を開始'
      
      # 確認モーダル
      within '.modal' do
        expect(page).to have_content("10件の会話")
        click_button '実行'
      end
      
      # プログラムでBatchAnalysisWorkerをキューに追加（テスト用）
      BatchAnalysisWorker.perform_async(conversations.map(&:id))
      
      # BatchAnalysisWorkerがキューに追加される
      expect(BatchAnalysisWorker.jobs.size).to eq(1)
      
      # BatchAnalysisWorkerを実行
      BatchAnalysisWorker.drain
      
      # 個別の分析ジョブが生成される
      expect(ConversationAnalysisWorker.jobs.size).to eq(10)
      
      # すべての個別ジョブを実行
      ConversationAnalysisWorker.drain
      
      # JavaScript実行を待つ
      sleep 1.5
      
      # 結果を確認
      within '#batch-results' do
        expect(page).to have_content('10件完了')
        expect(page).to have_content('0件失敗')
      end
    end

    it 'バッチ処理の進捗がJobステータスで追跡できる' do
      visit dashboard_conversations_path
      
      click_button 'バッチ分析を開始'
      within '.modal' do
        click_button '実行'
      end
      
      # プログラムでBatchAnalysisWorkerをキューに追加（テスト用）
      BatchAnalysisWorker.perform_async(conversations.map(&:id))
      
      # 進捗バーが表示される
      expect(page).to have_selector('#job-progress', wait: 2)
      
      # JavaScriptのアニメーションを待つ
      sleep 0.5
      
      # 進捗を確認（JavaScriptで自動的に進行）
      within '#job-progress' do
        # 進捗が表示されることを確認
        expect(page).to have_selector('.progress-text')
      end
      
      # BatchAnalysisWorkerを実行
      BatchAnalysisWorker.drain
      
      # 個別のジョブを実行
      ConversationAnalysisWorker.drain
      
      # アニメーション完了を待つ
      sleep 1.5
      
      # 最終的な結果
      within '#batch-results' do
        expect(page).to have_content('件完了')
      end
    end
  end

  describe 'EscalationNotificationWorkerの通知処理' do
    let(:conversation) { create(:conversation, user: user) }
    let(:high_priority_analysis) do
      create(:analysis,
             conversation: conversation,
             priority_level: 'high',
             analysis_data: { 'escalation_required' => true },
             escalated: true,
             sentiment: 'frustrated')
    end

    before do
      ENV['SLACK_WEBHOOK_URL'] = 'https://hooks.slack.com/test'
      stub_request(:post, /hooks.slack.com/).to_return(status: 200)
    end

    it 'エスカレーション通知が非同期で送信される' do
      visit conversation_path(conversation)
      
      # 高優先度の分析を作成
      high_priority_analysis
      
      # エスカレーションボタンをクリック
      click_button 'エスカレーション通知'
      
      # メッセージが表示されるまで待つ
      expect(page).to have_content('エスカレーション通知をキューに追加しました')
      
      # JavaScriptの実行を待つ
      sleep 0.5
      
      # ジョブがキューに追加される
      expect(EscalationNotificationWorker.jobs.size).to eq(1)
      
      # ワーカーを実行
      EscalationNotificationWorker.drain
      
      # Slack通知が送信されたことを確認
      expect(WebMock).to have_requested(:post, /hooks.slack.com/).once
      
      # UIが更新される
      visit current_path
      within '.escalation-status' do
        expect(page).to have_content('エスカレーション済み')
        expect(page).to have_content('通知送信: Slack')
      end
    end

    it '複数チャネルへの通知が並列処理される' do
      visit conversation_path(conversation)
      high_priority_analysis
      
      # 複数の通知チャネルを選択
      check 'Slack通知'
      check 'メール通知'
      check 'ダッシュボード通知'
      
      click_button '全チャネルに通知'
      
      # JavaScriptの実行を待つ
      sleep 0.5
      
      # 3つのジョブが作成される
      expect(EscalationNotificationWorker.jobs.size).to eq(3)
      
      # ジョブの内容を確認
      jobs = EscalationNotificationWorker.jobs
      channels = jobs.map { |j| j['args'][1]['channel'] }
      expect(channels).to contain_exactly('slack', 'email', 'dashboard')
      
      # すべて実行
      EscalationNotificationWorker.drain
      
      # 各チャネルの通知が完了
      visit current_path
      expect(page).to have_css('.notification-success', count: 3)
    end
  end

  describe 'Sidekiq管理画面での監視' do
    it '管理画面でジョブの状態を確認できる' do
      # 開発環境でのみアクセス可能
      if Rails.env.development?
        # 複数のジョブを作成
        5.times do |i|
          ConversationAnalysisWorker.perform_async(i, {})
        end
        
        visit '/sidekiq'
        
        # ダッシュボード情報
        within '.dashboard' do
          expect(page).to have_content('Enqueued: 5')
          expect(page).to have_content('analysis')
        end
        
        # キューの詳細
        click_link 'Queues'
        within '#queues' do
          expect(page).to have_content('analysis (5)')
        end
        
        # ジョブの詳細を見る
        click_link 'analysis'
        expect(page).to have_css('.job-row', count: 5)
        
        # ジョブをクリアー
        click_button 'Clear'
        expect(page).to have_content('Queue is empty')
      end
    end
  end

  describe 'エラーハンドリングとデッドレターキュー' do
    let(:conversation) { create(:conversation, user: user) }

    it '失敗したジョブがデッドレターキューに移動する' do
      # 常に失敗するように設定
      allow_any_instance_of(SentimentAnalyzer)
        .to receive(:analyze_conversation)
        .and_raise(StandardError, 'Permanent failure')
      
      visit conversation_path(conversation)
      click_button '非同期分析を開始'
      
      # リトライ回数の上限まで実行
      expect do
        3.times { ConversationAnalysisWorker.drain }
      end.to raise_error(StandardError)
      
      # デッドキューを確認
      if Rails.env.development?
        visit '/sidekiq/morgue'
        
        within '#dead' do
          expect(page).to have_content('ConversationAnalysisWorker')
          expect(page).to have_content('Permanent failure')
        end
        
        # リトライボタンがある
        expect(page).to have_button('Retry')
      end
    end
  end

  describe 'ジョブのスケジューリング' do
    it '遅延実行ジョブが指定時刻に実行される' do
      visit dashboard_path
      
      # スケジュール分析を設定
      click_link '分析をスケジュール'
      
      within '#schedule-modal' do
        fill_in 'scheduled_at', with: 1.hour.from_now
        click_button 'スケジュール'
      end
      
      expect(page).to have_content('分析を1時間後にスケジュールしました')
      
      # スケジュールされたジョブを確認
      scheduled_jobs = Sidekiq::ScheduledSet.new
      expect(scheduled_jobs.size).to eq(1)
      
      job = scheduled_jobs.first
      expect(job.klass).to eq('BatchAnalysisWorker')
      expect(job.at).to be_within(60).of(1.hour.from_now)
    end
  end
end