# frozen_string_literal: true

require 'rails_helper'
require 'sidekiq/testing'
require 'webmock/rspec'

RSpec.describe 'AI分析機能の統合テスト', type: :system do
  let(:user) { create(:user, email: 'test@example.com') }
  let(:conversation) { create(:conversation, user: user) }

  before do
    # Claude APIのモック
    allow_any_instance_of(ClaudeApiService).to receive(:analyze_conversation).and_return(
      'hidden_needs' => [
        { 'need_type' => '効率化', 'evidence' => '処理が遅い', 'confidence' => 0.8 }
      ],
      'customer_sentiment' => 'frustrated',
      'priority_level' => 'high',
      'escalation_required' => true
    )
    
    # SentimentAnalyzerのモックも設定（AnalysisStorageServiceが使用）
    allow_any_instance_of(SentimentAnalyzer).to receive(:analyze_conversation).and_return(
      overall_sentiment: 'frustrated',
      confidence_score: 1.0,
      sentiment_history: [
        { sentiment: { label: 'frustrated', confidence: 1.0 } }
      ],
      keyword_insights: {
        top_keywords: { '遅い' => 5 },
        insights: ['パフォーマンスに関する問題が繰り返し報告されています'],
        dominant_emotion: 'frustrated'
      },
      escalation_required: false,
      escalation_priority: 'low'  # priority_levelに使用される値を追加
    )
    
    # Sidekiqを同期モードに
    Sidekiq::Testing.inline!
  end

  describe '既存の会話に対する分析処理' do
    before do
      # テスト用メッセージを作成
      create(:message, conversation: conversation, role: 'user', content: 'システムが遅い')
      create(:message, conversation: conversation, role: 'assistant', content: 'お困りですね')
    end

    it '会話を分析して結果を保存する' do
      # 分析実行前の状態
      expect(conversation.analyses.count).to eq(0)
      
      # 分析ジョブを実行
      AnalyzeConversationJob.perform_now(conversation.id, use_worker: false)
      
      # 分析結果が保存される
      conversation.reload
      expect(conversation.analyses.count).to eq(1)
      
      analysis = conversation.analyses.last
      expect(analysis.sentiment).to eq('frustrated')
      expect(analysis.priority_level).to eq('high')
      expect(analysis.escalated).to be true
      expect(analysis.hidden_needs).to include(
        hash_including('need_type' => '効率化')
      )
    end

    it 'Sidekiqワーカーを使用して非同期分析を実行する' do
      # ワーカーを使用して分析（use_storage: trueでDBに保存）
      ConversationAnalysisWorker.perform_async(
        conversation.id,
        'use_storage' => true
      )
      
      # Sidekiq::Testing.inline!により即座に実行される
      conversation.reload
      expect(conversation.analyses.count).to eq(1)
    end
  end

  describe 'バッチ分析処理' do
    let(:conversations) { create_list(:conversation, 3, user: user) }

    before do
      conversations.each do |conv|
        create(:message, conversation: conv, role: 'user', content: '問題がある')
      end
    end

    it '複数の会話を一括で分析する' do
      conversation_ids = conversations.map(&:id)
      
      # バッチ分析を実行（use_storage: trueでDB保存を有効にする）
      BatchAnalysisWorker.new.perform(conversation_ids, { 'use_storage' => true })
      
      # 各会話に分析結果が保存される
      conversations.each do |conv|
        conv.reload
        expect(conv.analyses).not_to be_empty
        expect(conv.analyses.last.sentiment).to eq('frustrated')
      end
    end
  end

  describe 'エスカレーション通知' do
    let(:analysis) do
      create(:analysis,
             conversation: conversation,
             priority_level: 'high',
             analysis_data: { 'escalation_required' => true },
             escalated: false)
    end

    before do
      ENV['SLACK_WEBHOOK_URL'] = 'https://hooks.slack.com/test'
      stub_request(:post, /hooks.slack.com/).to_return(status: 200)
    end

    it 'エスカレーション通知を送信する' do
      # エスカレーション前の状態
      expect(analysis.escalated).to be false
      
      # エスカレーション通知を実行
      EscalationNotificationWorker.new.perform(analysis.id)
      
      # Slack通知が送信される
      expect(WebMock).to have_requested(:post, /hooks.slack.com/).once
      
      # エスカレーション状態が更新される
      analysis.reload
      expect(analysis.escalated).to be true
    end

    it '既にエスカレーション済みの場合はスキップする' do
      analysis.update!(escalated: true)
      
      # 通知ワーカーを実行
      EscalationNotificationWorker.new.perform(analysis.id)
      
      # Slack通知は送信されない
      expect(WebMock).not_to have_requested(:post, /hooks.slack.com/)
    end
  end

  describe 'エラーハンドリング' do
    it 'API エラー時にフォールバック分析を保存する' do
      # APIエラーをシミュレート
      allow_any_instance_of(ClaudeApiService)
        .to receive(:analyze_conversation)
        .and_raise(StandardError, 'API Error')
      
      # メッセージを作成
      create(:message, conversation: conversation, role: 'user', content: 'エラーテスト')
      
      # 分析を実行（エラーが発生）
      expect do
        AnalyzeConversationJob.perform_now(conversation.id, use_worker: false)
      end.not_to raise_error
      
      # フォールバック分析が保存される
      conversation.reload
      expect(conversation.analyses.count).to eq(1)
      
      analysis = conversation.analyses.last
      expect(analysis.analysis_data['fallback']).to be true
      expect(analysis.sentiment).to eq('neutral')
      expect(analysis.priority_level).to eq('low')
    end
  end

  describe 'リアルタイム更新' do
    it 'ActionCableで分析結果をブロードキャストする' do
      # メッセージ作成時のブロードキャストを許可
      allow(ActionCable.server).to receive(:broadcast).with(
        "conversation_#{conversation.id}",
        hash_including(:message)
      )
      
      # 分析完了時のブロードキャストを期待
      expect(ActionCable.server).to receive(:broadcast).with(
        "conversation_#{conversation.id}",
        hash_including(type: 'analysis_complete')
      ).once
      
      # メッセージを作成
      create(:message, conversation: conversation, role: 'user', content: 'テスト')
      
      # 分析を実行
      AnalyzeConversationJob.perform_now(conversation.id, use_worker: false)
    end
  end
end