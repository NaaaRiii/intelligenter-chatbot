# frozen_string_literal: true

require 'rails_helper'

RSpec.describe SolutionPrioritizationService do
  let(:service) { described_class.new }
  let(:vector_service) { VectorSearchService.new }
  
  describe '#prioritize_solutions' do
    context '問題に対する解決策の優先順位付け' do
      let(:problem_context) do
        {
          query: 'ログインできません',
          category: 'authentication',
          urgency: 'high',
          user_level: 'beginner'
        }
      end
      
      before do
        # 成功した解決パスのデータを準備
        create(:resolution_path,
               problem_type: 'login_issue',
               solution: 'パスワードリセット',
               steps_count: 2,
               resolution_time: 120,
               successful: true)
        create(:resolution_path,
               problem_type: 'login_issue',
               solution: 'キャッシュクリア',
               steps_count: 1,
               resolution_time: 60,
               successful: true)
        create(:resolution_path,
               problem_type: 'login_issue',
               solution: '二段階認証の無効化',
               steps_count: 4,
               resolution_time: 300,
               successful: false)
      end
      
      it '成功率の高い解決策を優先する' do
        solutions = service.prioritize_solutions(problem_context)
        
        expect(solutions).not_to be_empty
        expect(solutions.first[:solution]).to be_present
        expect(solutions.first[:success_rate]).to be > 0
        expect(solutions.first[:priority_score]).to be_present
      end
      
      it '優先度スコアでソートされた解決策リストを返す' do
        solutions = service.prioritize_solutions(problem_context)
        
        scores = solutions.map { |s| s[:priority_score] }
        expect(scores).to eq(scores.sort.reverse)
      end
      
      it '失敗した解決策は優先度を下げる' do
        solutions = service.prioritize_solutions(problem_context)
        
        failed_solution = solutions.find { |s| s[:solution] == '二段階認証の無効化' }
        successful_solution = solutions.find { |s| s[:solution] == 'パスワードリセット' }
        
        expect(failed_solution[:priority_score]).to be < successful_solution[:priority_score]
      end
    end
  end
  
  describe '#find_best_solution' do
    context '最適解の選択' do
      before do
        # 複数の成功パターンを作成
        5.times do |i|
          create(:resolution_path,
                 problem_type: 'payment_issue',
                 solution: "解決策#{i}",
                 steps_count: i + 1,
                 resolution_time: (i + 1) * 60,
                 successful: i < 3) # 最初の3つは成功
        end
      end
      
      it '最も効率的な成功解決策を返す' do
        best = service.find_best_solution('payment_issue')
        
        expect(best).to be_present
        expect(best[:solution]).to eq('解決策0')
        expect(best[:efficiency_score]).to be > 0
        expect(best[:confidence]).to be_between(0, 1)
      end
      
      it 'コンテキストを考慮した最適解を選択する' do
        context_params = {
          user_level: 'advanced',
          time_constraint: 'urgent',
          previous_attempts: ['解決策0']
        }
        
        best = service.find_best_solution('payment_issue', context: context_params)
        
        # 既に試した解決策は除外される
        expect(best[:solution]).not_to eq('解決策0')
      end
    end
  end
  
  describe '#rank_by_similarity' do
    context '類似問題の解決策ランキング' do
      before do
        # KnowledgeBaseに成功パターンを保存
        create(:knowledge_base,
               pattern_type: 'successful_conversation',
               content: { 
                 'problem' => 'ログインエラー',
                 'solution' => 'パスワードリセット'
               },
               success_score: 90,
               embedding: Array.new(1536) { rand(-1.0..1.0) })
        create(:knowledge_base,
               pattern_type: 'successful_conversation',
               content: { 
                 'problem' => 'アカウントロック',
                 'solution' => 'サポート問い合わせ'
               },
               success_score: 85,
               embedding: Array.new(1536) { rand(-1.0..1.0) })
      end
      
      it '類似度に基づいて解決策をランク付けする' do
        query = 'ログインできない問題'
        
        ranked = service.rank_by_similarity(query)
        
        expect(ranked).to be_an(Array)
        expect(ranked.first[:similarity_score]).to be_present
        expect(ranked.first[:solution]).to be_present
      end
      
      it '成功スコアと類似度を組み合わせて評価する' do
        query = 'アカウントにアクセスできない'
        
        ranked = service.rank_by_similarity(query)
        
        ranked.each do |item|
          expect(item[:combined_score]).to be_present
          expect(item[:combined_score]).to be_between(0, 100)
        end
      end
    end
  end
  
  describe '#calculate_priority_score' do
    it '複数の要因から優先度スコアを計算する' do
      solution_data = {
        success_rate: 0.8,
        average_time: 120,
        steps_count: 3,
        usage_count: 50,
        recent_success: true
      }
      
      score = service.calculate_priority_score(solution_data)
      
      expect(score).to be_a(Float)
      expect(score).to be_between(0, 100)
    end
    
    it '成功率を最も重視する' do
      high_success = {
        success_rate: 0.95,
        average_time: 300,
        steps_count: 5
      }
      
      low_success = {
        success_rate: 0.3,
        average_time: 60,
        steps_count: 1
      }
      
      high_score = service.calculate_priority_score(high_success)
      low_score = service.calculate_priority_score(low_success)
      
      expect(high_score).to be > low_score
    end
  end
  
  describe '#filter_by_constraints' do
    let(:solutions) do
      [
        { solution: '簡単な解決策', difficulty: 'easy', time_required: 60 },
        { solution: '中程度の解決策', difficulty: 'medium', time_required: 180 },
        { solution: '高度な解決策', difficulty: 'hard', time_required: 600 }
      ]
    end
    
    it 'ユーザーレベルに応じて解決策をフィルタリングする' do
      filtered = service.filter_by_constraints(solutions, user_level: 'beginner')
      
      expect(filtered).not_to include(hash_including(difficulty: 'hard'))
      expect(filtered).to include(hash_including(difficulty: 'easy'))
    end
    
    it '時間制約に応じて解決策をフィルタリングする' do
      filtered = service.filter_by_constraints(solutions, max_time: 120)
      
      expect(filtered.all? { |s| s[:time_required] <= 120 }).to be true
    end
  end
  
  describe '#enhance_with_context' do
    let(:base_solution) do
      {
        solution: 'パスワードリセット',
        steps: ['メールアドレス入力', 'リセットリンククリック', '新パスワード設定']
      }
    end
    
    it '解決策にコンテキスト情報を追加する' do
      context_info = {
        user_name: '山田様',
        previous_issues: ['ログインエラー'],
        account_type: 'premium'
      }
      
      enhanced = service.enhance_with_context(base_solution, context_info)
      
      expect(enhanced[:personalized]).to be true
      expect(enhanced[:greeting]).to include('山田様')
      expect(enhanced[:additional_info]).to be_present
    end
    
    it 'アカウントタイプに応じた特別対応を追加する' do
      vip_context = { account_type: 'vip' }
      
      enhanced = service.enhance_with_context(base_solution, vip_context)
      
      expect(enhanced[:priority_support]).to be true
      expect(enhanced[:escalation_available]).to be true
    end
  end
  
  describe '#track_solution_usage' do
    let(:solution) do
      {
        id: 'sol_001',
        solution: 'キャッシュクリア',
        problem_type: 'performance_issue'
      }
    end
    
    it '解決策の使用を記録する' do
      result = service.track_solution_usage(solution, outcome: 'successful')
      
      expect(result[:usage_count]).to eq(1)
      expect(result[:success_count]).to eq(1)
      expect(result[:last_used]).to be_present
    end
    
    it '使用統計を更新する' do
      # 複数回使用
      service.track_solution_usage(solution, outcome: 'successful')
      service.track_solution_usage(solution, outcome: 'failed')
      result = service.track_solution_usage(solution, outcome: 'successful')
      
      expect(result[:usage_count]).to eq(3)
      expect(result[:success_count]).to eq(2)
      expect(result[:success_rate]).to be_within(0.01).of(0.67)
    end
  end
  
  describe '#get_fallback_solutions' do
    it '主要解決策が失敗した場合の代替案を提供する' do
      problem_type = 'login_issue'
      failed_solution = 'パスワードリセット'
      
      fallbacks = service.get_fallback_solutions(problem_type, failed_solution)
      
      expect(fallbacks).to be_an(Array)
      expect(fallbacks).not_to be_empty
      expect(fallbacks.none? { |s| s[:solution] == failed_solution }).to be true
      expect(fallbacks.first[:is_fallback]).to be true
    end
    
    it 'エスカレーションオプションを含める' do
      fallbacks = service.get_fallback_solutions('complex_issue', 'self_service')
      
      escalation = fallbacks.find { |s| s[:type] == 'escalation' }
      expect(escalation).to be_present
      expect(escalation[:solution]).to include('サポート')
    end
  end
  
  describe '#analyze_solution_patterns' do
    before do
      # 複数の問題タイプと解決策のデータ
      10.times do |i|
        create(:resolution_path,
               problem_type: i < 5 ? 'type_a' : 'type_b',
               solution: i.even? ? 'solution_x' : 'solution_y',
               successful: i < 7)
      end
    end
    
    it '解決パターンを分析する' do
      patterns = service.analyze_solution_patterns
      
      expect(patterns[:most_successful_solution]).to be_present
      expect(patterns[:problem_solution_mapping]).to be_a(Hash)
      expect(patterns[:success_patterns]).to be_an(Array)
    end
    
    it '問題タイプごとの最適解をマッピングする' do
      patterns = service.analyze_solution_patterns
      
      mapping = patterns[:problem_solution_mapping]
      expect(mapping['type_a']).to be_present
      expect(mapping['type_b']).to be_present
    end
  end
  
  describe '#generate_solution_recommendation' do
    let(:conversation) { create(:conversation) }
    
    before do
      create(:message, conversation: conversation, role: 'user',
             content: 'ログインできません。パスワードを忘れました。')
      create(:message, conversation: conversation, role: 'assistant',
             content: 'パスワードリセットをご案内します。')
    end
    
    it '会話コンテキストから解決策を推奨する' do
      recommendation = service.generate_solution_recommendation(conversation)
      
      expect(recommendation[:primary_solution]).to be_present
      expect(recommendation[:confidence_level]).to be_between(0, 1)
      expect(recommendation[:reasoning]).to be_present
      expect(recommendation[:alternative_solutions]).to be_an(Array)
    end
    
    it '推奨理由を明確に説明する' do
      recommendation = service.generate_solution_recommendation(conversation)
      
      expect(recommendation[:reasoning]).to include('過去の成功率')
      expect(recommendation[:supporting_data]).to be_present
      expect(recommendation[:success_probability]).to be > 0
    end
  end
  
  describe '#optimize_solution_order' do
    let(:solutions) do
      [
        { solution: 'A', success_rate: 0.6, time: 100 },
        { solution: 'B', success_rate: 0.8, time: 200 },
        { solution: 'C', success_rate: 0.7, time: 50 }
      ]
    end
    
    it 'バランスの取れた順序で解決策を並べる' do
      optimized = service.optimize_solution_order(solutions)
      
      # 最初は成功率と速度のバランスが良いものを推奨
      expect(optimized.first[:solution]).to eq('C')
    end
    
    it '成功率重視モードで並べ替える' do
      optimized = service.optimize_solution_order(solutions, strategy: 'success_first')
      
      expect(optimized.first[:solution]).to eq('B')
      expect(optimized.first[:success_rate]).to eq(0.8)
    end
    
    it '速度重視モードで並べ替える' do
      optimized = service.optimize_solution_order(solutions, strategy: 'speed_first')
      
      expect(optimized.first[:solution]).to eq('C')
      expect(optimized.first[:time]).to eq(50)
    end
  end
end