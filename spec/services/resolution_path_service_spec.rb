# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ResolutionPathService do
  let(:service) { described_class.new }
  let(:conversation) { create(:conversation) }
  
  describe '#record_path' do
    context '問題解決パスの記録' do
      before do
        # 問題解決までの会話
        create(:message, conversation: conversation, role: 'user',
               content: 'ログインできません', created_at: 1.minute.ago)
        create(:message, conversation: conversation, role: 'assistant',
               content: 'パスワードをリセットしてみてください', created_at: 50.seconds.ago)
        create(:message, conversation: conversation, role: 'user',
               content: 'リセットメールが届きません', created_at: 40.seconds.ago)
        create(:message, conversation: conversation, role: 'assistant',
               content: 'スパムフォルダをご確認ください', created_at: 30.seconds.ago)
        create(:message, conversation: conversation, role: 'user',
               content: 'ありました！解決しました', created_at: 20.seconds.ago)
      end
      
      it '解決までのパスを記録する' do
        path = service.record_path(conversation)
        
        expect(path[:problem]).to eq('ログインできません')
        expect(path[:solution]).to include('スパムフォルダ')
        expect(path[:steps_count]).to eq(2)  # user-assistantペアが2組
        expect(path[:resolution_time]).to be < 60
        expect(path[:successful]).to be true
      end
      
      it '重要なステップを抽出する' do
        path = service.record_path(conversation)
        
        expect(path[:key_steps]).to be_an(Array)
        expect(path[:key_steps]).to include(
          hash_including(
            action: 'パスワードリセット',
            result: 'メール未着'
          )
        )
        expect(path[:key_steps]).to include(
          hash_including(
            action: 'スパムフォルダ確認',
            result: '解決'
          )
        )
      end
      
      it 'パスの効率性を評価する' do
        path = service.record_path(conversation)
        
        expect(path[:efficiency_score]).to be_between(0, 100)
        expect(path[:bottlenecks]).to be_an(Array)
        expect(path[:optimal_path_suggested]).to be_present
      end
    end
    
    context '未解決の場合' do
      before do
        create(:message, conversation: conversation, role: 'user',
               content: 'エラーが発生します')
        create(:message, conversation: conversation, role: 'assistant',
               content: '詳細を教えてください')
        create(:message, conversation: conversation, role: 'user',
               content: 'よくわかりません。もういいです')
      end
      
      it '未解決パスとして記録する' do
        path = service.record_path(conversation)
        
        expect(path[:successful]).to be false
        expect(path[:abandonment_point]).to eq('情報不足')
        expect(path[:improvement_suggestions]).to be_present
      end
    end
  end
  
  describe '#analyze_resolution_pattern' do
    it '解決パターンを分析する' do
      paths = [
        { problem: 'ログイン問題', solution: 'パスワードリセット', steps_count: 2, successful: true },
        { problem: 'ログイン問題', solution: 'キャッシュクリア', steps_count: 3, successful: true },
        { problem: 'ログイン問題', solution: 'パスワードリセット', steps_count: 2, successful: false }
      ]
      
      pattern = service.analyze_resolution_pattern(paths)
      
      expect(pattern[:most_common_solution]).to eq('パスワードリセット')
      expect(pattern[:average_steps]).to eq(2.3)
      expect(pattern[:success_rate]).to be > 0
      expect(pattern[:recommended_first_action]).to be_present
    end
  end
  
  describe '#find_shortest_path' do
    before do
      # 複数の解決パスをデータベースに保存
      create(:resolution_path,
             problem_type: 'login_issue',
             solution: 'パスワードリセット',
             steps_count: 2,
             resolution_time: 30,
             successful: true)
      create(:resolution_path,
             problem_type: 'login_issue',
             solution: 'アカウント再作成',
             steps_count: 5,
             resolution_time: 180,
             successful: true)
    end
    
    it '最短の解決パスを見つける' do
      shortest = service.find_shortest_path('login_issue')
      
      expect(shortest[:steps_count]).to eq(2)
      expect(shortest[:solution]).to eq('パスワードリセット')
      expect(shortest[:average_time]).to eq(30)
      expect(shortest[:reliability_score]).to be > 0
    end
    
    it '複数の評価基準で最適パスを選択する' do
      optimal = service.find_optimal_path(
        problem_type: 'login_issue',
        criteria: [:speed, :reliability, :simplicity]
      )
      
      expect(optimal[:path]).to be_present
      expect(optimal[:score_breakdown]).to include(:speed_score)
      expect(optimal[:score_breakdown]).to include(:reliability_score)
      expect(optimal[:total_score]).to be > 0
    end
  end
  
  describe '#generate_resolution_guide' do
    let(:problem_type) { 'payment_issue' }
    
    before do
      # 成功した解決パスのデータ
      create(:resolution_path,
             problem_type: problem_type,
             solution: 'カード情報更新',
             steps_count: 3,
             key_actions: ['エラー確認', 'カード有効期限チェック', '情報更新'],
             successful: true)
    end
    
    it '問題タイプから解決ガイドを生成する' do
      guide = service.generate_resolution_guide(problem_type)
      
      expect(guide[:recommended_steps]).to be_an(Array)
      expect(guide[:recommended_steps].first).to include(:action)
      expect(guide[:recommended_steps].first).to include(:expected_outcome)
      expect(guide[:estimated_time]).to be_present
      expect(guide[:success_probability]).to be > 0
    end
    
    it '代替パスも提供する' do
      guide = service.generate_resolution_guide(problem_type)
      
      expect(guide[:alternative_paths]).to be_an(Array)
      expect(guide[:alternative_paths]).not_to be_empty
      expect(guide[:escalation_trigger]).to be_present
    end
  end
  
  describe '#optimize_path' do
    let(:current_path) do
      {
        steps: [
          { action: '状況確認', time: 60 },
          { action: '基本チェック', time: 120 },
          { action: '詳細調査', time: 180 },
          { action: '解決策提示', time: 30 }
        ]
      }
    end
    
    it '既存パスを最適化する' do
      optimized = service.optimize_path(current_path)
      
      expect(optimized[:steps].count).to be <= current_path[:steps].count
      expect(optimized[:total_time]).to be < current_path[:steps].sum { |s| s[:time] }
      expect(optimized[:removed_steps]).to be_present
      expect(optimized[:optimization_rationale]).to be_present
    end
    
    it '並列実行可能なステップを識別する' do
      optimized = service.optimize_path(current_path)
      
      expect(optimized[:parallel_steps]).to be_an(Array)
      expect(optimized[:time_saved]).to be > 0
      expect(optimized[:new_flow]).to be_present
    end
  end
  
  describe '#track_path_performance' do
    let(:path_id) { 'path_001' }
    
    it 'パスの使用実績を追跡する' do
      result = service.track_path_performance(
        path_id: path_id,
        outcome: 'successful',
        actual_time: 45,
        user_satisfaction: 4
      )
      
      expect(result[:usage_count]).to eq(1)
      expect(result[:success_rate]).to eq(1.0)
      expect(result[:average_time]).to eq(45)
      expect(result[:satisfaction_score]).to eq(4)
    end
    
    it '複数の使用から統計を集計する' do
      # 複数回の使用をシミュレート
      3.times do |i|
        service.track_path_performance(
          path_id: path_id,
          outcome: i == 2 ? 'failed' : 'successful',
          actual_time: 40 + i * 10
        )
      end
      
      stats = service.get_path_statistics(path_id)
      
      expect(stats[:total_uses]).to eq(3)
      expect(stats[:success_rate]).to eq(0.67)
      expect(stats[:average_time]).to eq(50)
    end
  end
  
  describe '#detect_inefficiencies' do
    let(:conversation_with_loops) { create(:conversation) }
    
    before do
      # ループや非効率なやり取りを含む会話
      create(:message, conversation: conversation_with_loops, 
             content: '機能Aについて', role: 'user')
      create(:message, conversation: conversation_with_loops, 
             content: '機能Aの説明', role: 'assistant')
      create(:message, conversation: conversation_with_loops, 
             content: 'やっぱり機能Bについて', role: 'user')
      create(:message, conversation: conversation_with_loops, 
             content: '機能Bの説明', role: 'assistant')
      create(:message, conversation: conversation_with_loops, 
             content: 'もう一度機能Aについて', role: 'user')
    end
    
    it '会話内の非効率性を検出する' do
      inefficiencies = service.detect_inefficiencies(conversation_with_loops)
      
      expect(inefficiencies[:loops_detected]).to be true
      expect(inefficiencies[:repeated_topics]).to include('機能A')
      expect(inefficiencies[:wasted_interactions]).to be > 0
      expect(inefficiencies[:efficiency_loss]).to be > 0
    end
    
    it '改善提案を生成する' do
      inefficiencies = service.detect_inefficiencies(conversation_with_loops)
      
      expect(inefficiencies[:improvements]).to be_an(Array)
      expect(inefficiencies[:improvements]).to include(
        hash_including(:type => 'consolidate_questions')
      )
      expect(inefficiencies[:optimal_sequence]).to be_present
    end
  end
  
  describe '#compare_paths' do
    let(:path1) do
      {
        id: 'path_1',
        steps_count: 3,
        resolution_time: 60,
        success_rate: 0.9
      }
    end
    
    let(:path2) do
      {
        id: 'path_2',
        steps_count: 5,
        resolution_time: 45,
        success_rate: 0.95
      }
    end
    
    it '複数のパスを比較する' do
      comparison = service.compare_paths([path1, path2])
      
      expect(comparison[:fastest]).to eq('path_2')
      expect(comparison[:most_reliable]).to eq('path_2')
      expect(comparison[:simplest]).to eq('path_1')
      expect(comparison[:overall_best]).to be_present
      expect(comparison[:trade_offs]).to be_present
    end
  end
  
  describe '#learn_from_failures' do
    let(:failed_paths) do
      [
        { problem: 'setup_issue', failure_point: 'requirements_check', reason: 'missing_dependency' },
        { problem: 'setup_issue', failure_point: 'requirements_check', reason: 'version_conflict' },
        { problem: 'setup_issue', failure_point: 'installation', reason: 'permission_denied' }
      ]
    end
    
    it '失敗パターンから学習する' do
      learnings = service.learn_from_failures(failed_paths)
      
      expect(learnings[:common_failure_points]).to include('requirements_check')
      expect(learnings[:preventive_measures]).to be_present
      expect(learnings[:pre_checks]).to be_an(Array)
      expect(learnings[:success_rate_improvement]).to be > 0
    end
  end
end