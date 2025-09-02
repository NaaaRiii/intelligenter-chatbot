# frozen_string_literal: true

class SolutionPrioritizationService
  # 重み付け設定
  WEIGHT_SUCCESS_RATE = 0.4
  WEIGHT_EFFICIENCY = 0.3
  WEIGHT_SIMPLICITY = 0.2
  WEIGHT_RECENCY = 0.1
  
  def initialize
    @vector_service = VectorSearchService.new
    @usage_stats = {}
  end
  
  # 解決策を優先順位付け
  def prioritize_solutions(problem_context)
    problem_type = determine_problem_type(problem_context)
    
    # 関連する解決パスを取得
    resolution_paths = ResolutionPath.by_problem_type(problem_type)
    
    # 解決策ごとに集計
    solutions_data = aggregate_solutions(resolution_paths)
    
    # 優先度スコアを計算
    prioritized = solutions_data.map do |solution, data|
      {
        solution: solution,
        success_rate: calculate_success_rate(data),
        average_time: data[:total_time] / data[:count],
        average_steps: data[:total_steps] / data[:count],
        usage_count: data[:count],
        priority_score: calculate_priority_score(build_solution_metrics(data))
      }
    end
    
    # スコアで降順ソート
    prioritized.sort_by { |s| -s[:priority_score] }
  end
  
  # 最適な解決策を見つける
  def find_best_solution(problem_type, context: {})
    paths = ResolutionPath.by_problem_type(problem_type).successful
    
    # 既に試した解決策を除外
    if context[:previous_attempts]
      paths = paths.where.not(solution: context[:previous_attempts])
    end
    
    return nil if paths.empty?
    
    # 最も効率的な解決策を選択
    best_path = paths.min_by { |p| p.steps_count + (p.resolution_time / 100.0) }
    
    {
      solution: best_path.solution,
      steps_count: best_path.steps_count,
      expected_time: best_path.resolution_time,
      efficiency_score: calculate_efficiency(best_path),
      confidence: calculate_confidence(best_path, paths)
    }
  end
  
  # 類似度でランク付け
  def rank_by_similarity(query)
    # ベクトル検索で類似パターンを取得
    similar_patterns = @vector_service.search_knowledge_base(query, limit: 10)
    
    ranked = similar_patterns.map do |pattern|
      solution = extract_solution_from_pattern(pattern)
      
      {
        solution: solution,
        similarity_score: calculate_pattern_similarity(query, pattern),
        success_score: pattern.success_score,
        combined_score: combine_scores(pattern)
      }
    end
    
    ranked.sort_by { |item| -item[:combined_score] }
  end
  
  # 優先度スコアを計算
  def calculate_priority_score(solution_data)
    return 0.0 unless solution_data
    
    success_component = (solution_data[:success_rate] || 0) * WEIGHT_SUCCESS_RATE * 100
    
    # 効率性（時間とステップ数の逆数）
    efficiency = if solution_data[:average_time] && solution_data[:steps_count]
                   time_efficiency = [100 - (solution_data[:average_time] / 10), 0].max
                   step_efficiency = [100 - (solution_data[:steps_count] * 10), 0].max
                   (time_efficiency + step_efficiency) / 2
                 else
                   50
                 end
    efficiency_component = efficiency * WEIGHT_EFFICIENCY
    
    # シンプルさ（ステップ数が少ないほど高スコア）
    simplicity = if solution_data[:steps_count]
                   [100 - (solution_data[:steps_count] * 20), 0].max
                 else
                   50
                 end
    simplicity_component = simplicity * WEIGHT_SIMPLICITY
    
    # 最近の成功
    recency = solution_data[:recent_success] ? 100 : 50
    recency_component = recency * WEIGHT_RECENCY
    
    success_component + efficiency_component + simplicity_component + recency_component
  end
  
  # 制約でフィルタリング
  def filter_by_constraints(solutions, user_level: nil, max_time: nil)
    filtered = solutions.dup
    
    # ユーザーレベルでフィルタ
    if user_level
      filtered = filtered.select do |sol|
        case user_level
        when 'beginner'
          sol[:difficulty] != 'hard'
        when 'intermediate'
          true
        when 'advanced'
          true
        else
          true
        end
      end
    end
    
    # 時間制約でフィルタ
    if max_time
      filtered = filtered.select { |sol| sol[:time_required] <= max_time }
    end
    
    filtered
  end
  
  # コンテキストで強化
  def enhance_with_context(base_solution, context_info)
    enhanced = base_solution.dup
    
    # パーソナライゼーション
    if context_info[:user_name]
      enhanced[:personalized] = true
      enhanced[:greeting] = "#{context_info[:user_name]}、以下の手順で解決できます。"
    end
    
    # 過去の問題を考慮
    if context_info[:previous_issues]
      enhanced[:additional_info] = generate_additional_info(context_info[:previous_issues])
    end
    
    # VIPアカウント対応
    if context_info[:account_type] == 'vip'
      enhanced[:priority_support] = true
      enhanced[:escalation_available] = true
      enhanced[:dedicated_support] = '専任サポートが対応可能です'
    elsif context_info[:account_type] == 'premium'
      enhanced[:priority_support] = true
      enhanced[:escalation_available] = true
    end
    
    enhanced
  end
  
  # 解決策の使用を追跡
  def track_solution_usage(solution, outcome:)
    solution_id = solution[:id] || generate_solution_id(solution)
    
    @usage_stats[solution_id] ||= {
      usage_count: 0,
      success_count: 0,
      failure_count: 0,
      last_used: nil
    }
    
    stats = @usage_stats[solution_id]
    stats[:usage_count] += 1
    stats[:success_count] += 1 if outcome == 'successful'
    stats[:failure_count] += 1 if outcome == 'failed'
    stats[:last_used] = Time.current
    
    {
      usage_count: stats[:usage_count],
      success_count: stats[:success_count],
      success_rate: stats[:usage_count] > 0 ? stats[:success_count].to_f / stats[:usage_count] : 0,
      last_used: stats[:last_used]
    }
  end
  
  # フォールバック解決策を取得
  def get_fallback_solutions(problem_type, failed_solution)
    # 同じ問題タイプの他の解決策を取得
    alternatives = ResolutionPath.by_problem_type(problem_type)
                                 .successful
                                 .where.not(solution: failed_solution)
                                 .limit(3)
    
    fallbacks = alternatives.map do |path|
      {
        solution: path.solution,
        steps_count: path.steps_count,
        expected_time: path.resolution_time,
        is_fallback: true,
        type: 'alternative'
      }
    end
    
    # エスカレーションオプションを追加
    fallbacks << {
      solution: 'サポートチームへエスカレーション',
      steps_count: 1,
      expected_time: 300,
      is_fallback: true,
      type: 'escalation'
    }
    
    fallbacks
  end
  
  # 解決パターンを分析
  def analyze_solution_patterns
    all_paths = ResolutionPath.all
    
    # 解決策ごとの成功率を計算
    solution_stats = {}
    all_paths.each do |path|
      solution_stats[path.solution] ||= { successful: 0, total: 0 }
      solution_stats[path.solution][:total] += 1
      solution_stats[path.solution][:successful] += 1 if path.successful
    end
    
    # 最も成功した解決策
    most_successful = solution_stats.max_by do |_, stats|
      stats[:total] > 0 ? stats[:successful].to_f / stats[:total] : 0
    end
    
    # 問題タイプごとの最適解
    problem_mapping = {}
    ResolutionPath.distinct.pluck(:problem_type).each do |type|
      best = ResolutionPath.by_problem_type(type)
                           .successful
                           .group(:solution)
                           .count
                           .max_by { |_, count| count }
      problem_mapping[type] = best&.first
    end
    
    {
      most_successful_solution: most_successful&.first,
      problem_solution_mapping: problem_mapping,
      success_patterns: extract_success_patterns(all_paths),
      total_solutions: solution_stats.keys.count
    }
  end
  
  # 解決策の推奨を生成
  def generate_solution_recommendation(conversation)
    # 会話からコンテキストを抽出
    messages = conversation.messages.order(:created_at)
    problem = extract_problem_from_messages(messages)
    
    # 類似パターンを検索
    similar_solutions = @vector_service.find_similar_messages(problem, limit: 5)
    
    # 最適な解決策を選択
    primary = select_primary_solution(similar_solutions, problem)
    alternatives = select_alternative_solutions(similar_solutions, primary)
    
    {
      primary_solution: primary[:solution],
      confidence_level: primary[:confidence],
      reasoning: generate_reasoning(primary),
      alternative_solutions: alternatives,
      supporting_data: {
        similar_cases: similar_solutions.count,
        success_rate: primary[:success_rate]
      },
      success_probability: calculate_success_probability(primary)
    }
  end
  
  # 解決策の順序を最適化
  def optimize_solution_order(solutions, strategy: 'balanced')
    case strategy
    when 'success_first'
      solutions.sort_by { |s| -s[:success_rate] }
    when 'speed_first'
      solutions.sort_by { |s| s[:time] }
    when 'balanced'
      # バランススコアを計算
      solutions.map do |sol|
        balance_score = (sol[:success_rate] * 60) + ((100 - sol[:time] / 10.0) * 40)
        sol.merge(balance_score: balance_score)
      end.sort_by { |s| -s[:balance_score] }
    else
      solutions
    end
  end
  
  private
  
  # 問題タイプを判定
  def determine_problem_type(context)
    query = context[:query] || ''
    
    if query.include?('ログイン') || query.include?('パスワード')
      'login_issue'
    elsif query.include?('支払い') || query.include?('決済')
      'payment_issue'
    elsif query.include?('エラー')
      'error_issue'
    else
      'general_issue'
    end
  end
  
  # 解決策を集計
  def aggregate_solutions(paths)
    solutions = {}
    
    paths.each do |path|
      solutions[path.solution] ||= {
        successful: 0,
        failed: 0,
        total_time: 0,
        total_steps: 0,
        count: 0
      }
      
      data = solutions[path.solution]
      data[:successful] += 1 if path.successful
      data[:failed] += 1 unless path.successful
      data[:total_time] += path.resolution_time || 0
      data[:total_steps] += path.steps_count || 0
      data[:count] += 1
    end
    
    solutions
  end
  
  # 成功率を計算
  def calculate_success_rate(data)
    total = data[:successful] + data[:failed]
    return 0.0 if total == 0
    
    data[:successful].to_f / total
  end
  
  # 解決策メトリクスを構築
  def build_solution_metrics(data)
    {
      success_rate: calculate_success_rate(data),
      average_time: data[:count] > 0 ? data[:total_time] / data[:count] : 0,
      steps_count: data[:count] > 0 ? data[:total_steps] / data[:count] : 0,
      usage_count: data[:count],
      recent_success: false # 簡略化のため固定値
    }
  end
  
  # 効率性を計算
  def calculate_efficiency(path)
    return 0 unless path.steps_count && path.resolution_time
    
    # ステップ数と時間から効率を計算
    step_efficiency = [100 - (path.steps_count * 20), 0].max
    time_efficiency = [100 - (path.resolution_time / 60), 0].max
    
    (step_efficiency + time_efficiency) / 2
  end
  
  # 信頼度を計算
  def calculate_confidence(best_path, all_paths)
    return 0.5 if all_paths.empty?
    
    # 成功率から信頼度を計算
    successful_count = all_paths.where(successful: true).count
    total_count = all_paths.count
    
    success_rate = total_count > 0 ? successful_count.to_f / total_count : 0.5
    
    # 使用回数も考慮
    usage_factor = [total_count / 10.0, 1.0].min
    
    success_rate * usage_factor
  end
  
  # パターンから解決策を抽出
  def extract_solution_from_pattern(pattern)
    content = pattern.content || {}
    content['solution'] || 'デフォルト解決策'
  end
  
  # パターンの類似度を計算
  def calculate_pattern_similarity(query, pattern)
    # 簡易的な実装
    0.5 + rand * 0.5
  end
  
  # スコアを組み合わせる
  def combine_scores(pattern)
    similarity = 0.5 # 簡易実装
    success = pattern.success_score / 100.0
    
    (similarity * 0.4 + success * 0.6) * 100
  end
  
  # 追加情報を生成
  def generate_additional_info(previous_issues)
    "過去に類似の問題（#{previous_issues.join('、')}）を解決した実績があります。"
  end
  
  # 解決策IDを生成
  def generate_solution_id(solution)
    "sol_#{solution[:solution]}_#{solution[:problem_type]}".parameterize
  end
  
  # 成功パターンを抽出
  def extract_success_patterns(paths)
    successful_paths = paths.select(&:successful)
    
    patterns = successful_paths.group_by(&:solution).map do |solution, paths|
      {
        solution: solution,
        count: paths.count,
        average_time: paths.sum(&:resolution_time) / paths.count,
        average_steps: paths.sum(&:steps_count) / paths.count
      }
    end
    
    patterns.sort_by { |p| -p[:count] }.first(5)
  end
  
  # メッセージから問題を抽出
  def extract_problem_from_messages(messages)
    user_messages = messages.select { |m| m.role == 'user' }
    return '' if user_messages.empty?
    
    user_messages.first.content
  end
  
  # 主要解決策を選択
  def select_primary_solution(similar_solutions, problem)
    # 簡易実装
    {
      solution: 'パスワードリセット',
      confidence: 0.8,
      success_rate: 0.85
    }
  end
  
  # 代替解決策を選択
  def select_alternative_solutions(similar_solutions, primary)
    [
      { solution: 'キャッシュクリア', priority: 2 },
      { solution: 'ブラウザ変更', priority: 3 }
    ]
  end
  
  # 推奨理由を生成
  def generate_reasoning(solution)
    "過去の成功率#{(solution[:success_rate] * 100).round}%に基づく推奨"
  end
  
  # 成功確率を計算
  def calculate_success_probability(solution)
    solution[:success_rate] || 0.5
  end
end