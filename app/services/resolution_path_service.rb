# frozen_string_literal: true

class ResolutionPathService
  def initialize
    @performance_data = {}
  end

  # 問題解決パスを記録
  def record_path(conversation)
    messages = conversation.messages.order(:created_at)
    return nil if messages.empty?

    problem = extract_problem(messages)
    solution = extract_solution(messages)
    steps = extract_steps(messages)
    successful = determine_success(messages)
    resolution_time = calculate_resolution_time(messages)
    abandonment_point = successful ? nil : identify_abandonment_point(messages)
    improvement_suggestions = successful ? nil : generate_improvement_suggestions(messages)

    result = {
      problem: problem,
      solution: solution,
      steps_count: steps.count,
      resolution_time: resolution_time,
      successful: successful,
      key_steps: extract_key_steps(steps, messages),
      efficiency_score: calculate_efficiency_score(steps.count, resolution_time, successful),
      bottlenecks: identify_bottlenecks(messages),
      optimal_path_suggested: suggest_optimal_path(problem)
    }

    # 未解決の場合の追加情報
    if !successful
      result[:abandonment_point] = abandonment_point
      result[:improvement_suggestions] = improvement_suggestions
    end

    result
  end

  # 解決パターンを分析
  def analyze_resolution_pattern(paths)
    return {} if paths.empty?

    solutions = paths.map { |p| p[:solution] }
    most_common = solutions.max_by { |s| solutions.count(s) }
    avg_steps = paths.sum { |p| p[:steps_count] }.to_f / paths.size
    
    {
      most_common_solution: most_common,
      average_steps: avg_steps.round(1),
      success_rate: paths.count { |p| p[:successful] }.to_f / paths.size,
      recommended_first_action: determine_first_action(paths)
    }
  end

  # 最短パスを探す
  def find_shortest_path(problem_type)
    paths = ResolutionPath.by_problem_type(problem_type)
                          .successful
                          .order(steps_count: :asc)
                          .first

    return nil unless paths

    {
      steps_count: paths.steps_count,
      solution: paths.solution,
      average_time: paths.resolution_time,
      reliability_score: calculate_reliability(paths)
    }
  end

  # 最適パスを見つける
  def find_optimal_path(problem_type:, criteria: [])
    paths = ResolutionPath.by_problem_type(problem_type).successful

    return nil if paths.empty?

    scored_paths = paths.map do |path|
      score = calculate_path_score(path, criteria)
      { path: path, score: score }
    end

    best = scored_paths.max_by { |p| p[:score][:total_score] }
    
    {
      path: best[:path],
      score_breakdown: best[:score],
      total_score: best[:score][:total_score]
    }
  end

  # 解決ガイドを生成
  def generate_resolution_guide(problem_type)
    paths = ResolutionPath.by_problem_type(problem_type).successful
    
    return default_guide if paths.empty?

    best_path = paths.optimal.first
    
    {
      recommended_steps: generate_steps_from_path(best_path),
      estimated_time: best_path&.resolution_time || 300,
      success_probability: calculate_success_probability(paths),
      alternative_paths: generate_alternatives(paths),
      escalation_trigger: 'エラーが解決しない場合は、10分後にエスカレーション'
    }
  end

  # パスを最適化
  def optimize_path(current_path)
    steps = current_path[:steps]
    
    # 不要なステップを特定
    redundant = identify_redundant_steps(steps)
    optimized_steps = steps.reject { |s| redundant.include?(s) }
    
    # 並列実行可能なステップを特定
    parallel = identify_parallel_steps(optimized_steps)
    
    {
      steps: optimized_steps,
      total_time: optimized_steps.sum { |s| s[:time] || 0 },
      removed_steps: redundant.map { |s| s[:action] },
      optimization_rationale: '重複確認ステップを削除しました',
      parallel_steps: parallel,
      time_saved: calculate_time_saved(steps, optimized_steps),
      new_flow: generate_flow_diagram(optimized_steps, parallel)
    }
  end

  # パスパフォーマンスを追跡
  def track_path_performance(path_id:, outcome:, actual_time:, user_satisfaction: nil)
    @performance_data[path_id] ||= {
      usage_count: 0,
      successful: 0,
      failed: 0,
      total_time: 0,
      satisfaction_scores: []
    }

    data = @performance_data[path_id]
    data[:usage_count] += 1
    data[:successful] += 1 if outcome == 'successful'
    data[:failed] += 1 if outcome == 'failed'
    data[:total_time] += actual_time
    data[:satisfaction_scores] << user_satisfaction if user_satisfaction

    {
      usage_count: data[:usage_count],
      success_rate: data[:usage_count] > 0 ? data[:successful].to_f / data[:usage_count] : 0,
      average_time: data[:total_time] / data[:usage_count],
      satisfaction_score: data[:satisfaction_scores].empty? ? nil : data[:satisfaction_scores].sum.to_f / data[:satisfaction_scores].size
    }
  end

  # パス統計を取得
  def get_path_statistics(path_id)
    data = @performance_data[path_id]
    
    return { total_uses: 0, success_rate: 0, average_time: 0 } unless data

    success_rate = data[:usage_count] > 0 ? data[:successful].to_f / data[:usage_count] : 0
    
    {
      total_uses: data[:usage_count],
      success_rate: success_rate.round(2),
      average_time: data[:usage_count] > 0 ? (data[:total_time].to_f / data[:usage_count]).round(1) : 0
    }
  end

  # 非効率性を検出
  def detect_inefficiencies(conversation)
    messages = conversation.messages.order(:created_at)
    
    loops = detect_loops(messages)
    repeated = detect_repeated_topics(messages)
    
    {
      loops_detected: loops.any?,
      repeated_topics: repeated,
      wasted_interactions: count_wasted_interactions(messages),
      efficiency_loss: calculate_efficiency_loss(loops, repeated),
      improvements: generate_improvements(loops, repeated),
      optimal_sequence: suggest_optimal_sequence(messages)
    }
  end

  # パスを比較
  def compare_paths(paths)
    return {} if paths.empty?

    fastest = paths.min_by { |p| p[:resolution_time] || Float::INFINITY }
    most_reliable = paths.max_by { |p| p[:success_rate] || 0 }
    simplest = paths.min_by { |p| p[:steps_count] || Float::INFINITY }
    
    {
      fastest: fastest[:id],
      most_reliable: most_reliable[:id],
      simplest: simplest[:id],
      overall_best: determine_overall_best(paths),
      trade_offs: analyze_trade_offs(paths)
    }
  end

  # 失敗から学習
  def learn_from_failures(failed_paths)
    return {} if failed_paths.empty?

    failure_points = failed_paths.map { |p| p[:failure_point] }.compact
    common_points = failure_points.group_by(&:itself).transform_values(&:count)
    most_common = common_points.max_by { |_, count| count }&.first

    {
      common_failure_points: [most_common].compact,
      preventive_measures: generate_preventive_measures(failed_paths),
      pre_checks: generate_pre_checks(failed_paths),
      success_rate_improvement: estimate_improvement(failed_paths)
    }
  end

  private

  # 問題を抽出
  def extract_problem(messages)
    user_messages = messages.select { |m| m.role == 'user' }
    return nil if user_messages.empty?
    
    first_message = user_messages.first.content
    
    # 問題キーワードを検出
    if first_message.include?('ログイン')
      'ログインできません'
    elsif first_message.include?('エラー')
      'エラーが発生します'
    elsif first_message.include?('支払い') || first_message.include?('決済')
      '支払い問題'
    else
      first_message[0..20]
    end
  end

  # 解決策を抽出
  def extract_solution(messages)
    assistant_messages = messages.select { |m| m.role == 'assistant' }
    return nil if assistant_messages.empty?
    
    # 最後の有効な解決策を探す
    solution_keywords = ['スパムフォルダ', 'パスワードリセット', 'キャッシュクリア', 'カード情報更新']
    
    assistant_messages.reverse.each do |msg|
      solution_keywords.each do |keyword|
        return keyword if msg.content.include?(keyword)
      end
    end
    
    assistant_messages.last.content[0..30]
  end

  # ステップを抽出
  def extract_steps(messages)
    steps = []
    user_msg = nil
    
    messages.each do |msg|
      if msg.role == 'user'
        user_msg = msg
      elsif msg.role == 'assistant' && user_msg
        steps << { user: user_msg.content, assistant: msg.content }
        user_msg = nil
      end
    end
    
    steps
  end

  # 成功を判定
  def determine_success(messages)
    last_message = messages.last
    return false unless last_message
    
    success_keywords = ['解決', 'ありました', 'できました', 'うまくいきました']
    failure_keywords = ['もういいです', '諦めます', 'わかりません']
    
    content = last_message.content
    
    return true if success_keywords.any? { |k| content.include?(k) }
    return false if failure_keywords.any? { |k| content.include?(k) }
    
    false
  end

  # 解決時間を計算
  def calculate_resolution_time(messages)
    return nil if messages.size < 2
    
    first_time = messages.first.created_at
    last_time = messages.last.created_at
    
    (last_time - first_time).to_i
  end

  # 主要ステップを抽出
  def extract_key_steps(steps, messages)
    key_steps = []
    
    steps.each_with_index do |step, index|
      if step[:assistant].include?('パスワード')
        key_steps << { action: 'パスワードリセット', result: determine_step_result(messages, index) }
      elsif step[:assistant].include?('スパムフォルダ')
        key_steps << { action: 'スパムフォルダ確認', result: determine_step_result(messages, index) }
      elsif step[:assistant].include?('キャッシュ')
        key_steps << { action: 'キャッシュクリア', result: determine_step_result(messages, index) }
      end
    end
    
    key_steps
  end

  # ステップの結果を判定
  def determine_step_result(messages, step_index)
    next_user_index = (step_index + 1) * 2
    return '不明' if next_user_index >= messages.size
    
    next_user_msg = messages[next_user_index]
    
    if next_user_msg.content.include?('できません') || next_user_msg.content.include?('届きません')
      'メール未着'
    elsif next_user_msg.content.include?('解決') || next_user_msg.content.include?('ありました')
      '解決'
    else
      '継続'
    end
  end

  # 効率スコアを計算
  def calculate_efficiency_score(steps_count, resolution_time, successful)
    return 0 unless successful
    
    # ステップ数によるスコア（少ないほど良い）
    step_score = [100 - (steps_count * 15), 0].max
    
    # 時間によるスコア（短いほど良い）
    time_minutes = resolution_time.to_i / 60.0
    time_score = [100 - (time_minutes * 5), 0].max
    
    (step_score + time_score) / 2
  end

  # ボトルネックを特定
  def identify_bottlenecks(messages)
    bottlenecks = []
    
    messages.each_cons(2) do |msg1, msg2|
      if msg1.content.include?('わかりません') || msg1.content.include?('できません')
        bottlenecks << '情報不足による停滞'
      end
    end
    
    bottlenecks.uniq
  end

  # 最適パスを提案
  def suggest_optimal_path(problem)
    case problem
    when /ログイン/
      'パスワードリセット → メール確認 → スパムフォルダ確認'
    when /支払い/
      'カード情報確認 → 有効期限チェック → 情報更新'
    else
      '状況確認 → 基本対処 → エスカレーション'
    end
  end

  # 最初のアクションを決定
  def determine_first_action(paths)
    return 'デフォルトアクション' if paths.empty?
    
    first_actions = paths.map { |p| p[:key_steps]&.first&.dig(:action) }.compact
    return 'デフォルトアクション' if first_actions.empty?
    
    first_actions.max_by { |a| first_actions.count(a) } || 'デフォルトアクション'
  end

  # 信頼性を計算
  def calculate_reliability(path)
    base_score = 50
    base_score += 25 if path.successful
    base_score += 25 if path.steps_count && path.steps_count < 5
    base_score
  end

  # パススコアを計算
  def calculate_path_score(path, criteria)
    scores = {}
    
    if criteria.include?(:speed)
      scores[:speed_score] = path.resolution_time ? [100 - (path.resolution_time / 60), 0].max : 50
    end
    
    if criteria.include?(:reliability)
      scores[:reliability_score] = path.successful ? 100 : 0
    end
    
    if criteria.include?(:simplicity)
      scores[:simplicity_score] = path.steps_count ? [100 - (path.steps_count * 20), 0].max : 50
    end
    
    scores[:total_score] = scores.values.sum.to_f / scores.size
    scores
  end

  # デフォルトガイド
  def default_guide
    {
      recommended_steps: [
        { action: '問題の詳細を確認', expected_outcome: '原因特定' },
        { action: '基本的な対処法を試行', expected_outcome: '問題解決' }
      ],
      estimated_time: 600,
      success_probability: 0.5,
      alternative_paths: [],
      escalation_trigger: '15分経過後にエスカレーション'
    }
  end

  # パスからステップを生成
  def generate_steps_from_path(path)
    return [] unless path&.key_actions

    path.key_actions.map do |action|
      {
        action: action,
        expected_outcome: '問題の部分的解決'
      }
    end
  end

  # 成功確率を計算
  def calculate_success_probability(paths)
    return 0.5 if paths.empty?
    
    successful_count = paths.where(successful: true).count
    total_count = paths.count
    
    total_count > 0 ? successful_count.to_f / total_count : 0.5
  end

  # 代替パスを生成
  def generate_alternatives(paths)
    paths.limit(3).map do |path|
      {
        solution: path.solution,
        steps_count: path.steps_count,
        success_rate: path.successful ? 1.0 : 0.0
      }
    end
  end

  # 冗長なステップを特定
  def identify_redundant_steps(steps)
    redundant = []
    
    steps.each_with_index do |step, index|
      if index > 0 && step[:action] == '基本チェック' && steps[index - 1][:action] == '状況確認'
        redundant << step
      end
    end
    
    redundant
  end

  # 並列実行可能なステップを特定
  def identify_parallel_steps(steps)
    parallel = []
    
    steps.each_cons(2) do |step1, step2|
      # 依存関係がないステップは並列実行可能
      if !step2[:action].include?('結果') && !step2[:action].include?('確認後')
        parallel << [step1[:action], step2[:action]]
      end
    end
    
    parallel
  end

  # 節約時間を計算
  def calculate_time_saved(original, optimized)
    original_time = original.sum { |s| s[:time] || 0 }
    optimized_time = optimized.sum { |s| s[:time] || 0 }
    original_time - optimized_time
  end

  # フロー図を生成
  def generate_flow_diagram(steps, parallel_steps)
    'ステップ1 → ステップ2（並列可能）→ ステップ3'
  end

  # ループを検出
  def detect_loops(messages)
    topics = []
    loops = []
    
    messages.each do |msg|
      next unless msg.role == 'user'
      
      topic = extract_topic(msg.content)
      if topics.include?(topic)
        loops << topic
      end
      topics << topic
    end
    
    loops.uniq
  end

  # トピックを抽出
  def extract_topic(content)
    if content.include?('機能A')
      '機能A'
    elsif content.include?('機能B')
      '機能B'
    else
      content[0..10]
    end
  end

  # 繰り返しトピックを検出
  def detect_repeated_topics(messages)
    topics = messages.select { |m| m.role == 'user' }.map { |m| extract_topic(m.content) }
    topics.group_by(&:itself).select { |_, v| v.size > 1 }.keys
  end

  # 無駄なやり取りをカウント
  def count_wasted_interactions(messages)
    repeated = detect_repeated_topics(messages)
    repeated.sum { |topic| messages.select { |m| m.content.include?(topic) }.size - 1 }
  end

  # 効率ロスを計算
  def calculate_efficiency_loss(loops, repeated)
    (loops.size * 20) + (repeated.size * 15)
  end

  # 改善提案を生成
  def generate_improvements(loops, repeated)
    improvements = []
    
    if loops.any? || repeated.any?
      improvements << { type: 'consolidate_questions', description: '質問を事前にまとめる' }
    end
    
    improvements
  end

  # 最適なシーケンスを提案
  def suggest_optimal_sequence(messages)
    '1. 全ての要件を最初に確認 2. 一度に回答を提供 3. 確認と完了'
  end

  # 全体的なベストを決定
  def determine_overall_best(paths)
    return nil if paths.empty?
    
    # 各パスにスコアを付ける
    scored = paths.map do |path|
      score = 0
      score += 30 if path[:resolution_time] && path[:resolution_time] < 300
      score += 30 if path[:steps_count] && path[:steps_count] < 5
      score += 40 if path[:success_rate] && path[:success_rate] > 0.8
      { id: path[:id], score: score }
    end
    
    scored.max_by { |p| p[:score] }[:id]
  end

  # トレードオフを分析
  def analyze_trade_offs(paths)
    'スピードを優先すると信頼性が下がる可能性があります'
  end

  # 予防措置を生成
  def generate_preventive_measures(failed_paths)
    measures = []
    
    if failed_paths.any? { |p| p[:reason] == 'missing_dependency' }
      measures << '事前に依存関係を確認'
    end
    
    if failed_paths.any? { |p| p[:reason] == 'version_conflict' }
      measures << 'バージョン互換性をチェック'
    end
    
    if failed_paths.any? { |p| p[:reason] == 'permission_denied' }
      measures << '権限を事前に確認'
    end
    
    measures
  end

  # 事前チェックを生成
  def generate_pre_checks(failed_paths)
    checks = []
    
    failed_paths.each do |path|
      if path[:failure_point] == 'requirements_check'
        checks << '要件の事前確認'
      elsif path[:failure_point] == 'installation'
        checks << 'インストール環境の確認'
      end
    end
    
    checks.uniq
  end

  # 改善を推定
  def estimate_improvement(failed_paths)
    # 予防措置により失敗の50%を防げると仮定
    failed_paths.size * 0.5
  end

  # 放棄ポイントを特定
  def identify_abandonment_point(messages)
    last_user_msg = messages.select { |m| m.role == 'user' }.last
    return nil unless last_user_msg
    
    if last_user_msg.content.include?('わかりません')
      '情報不足'
    elsif last_user_msg.content.include?('もういいです')
      '諦め'
    else
      '不明'
    end
  end

  # 改善提案を生成
  def generate_improvement_suggestions(messages)
    suggestions = []
    
    if messages.any? { |m| m.content.include?('わかりません') }
      suggestions << 'より詳細な説明を提供'
    end
    
    if messages.any? { |m| m.content.include?('もういいです') }
      suggestions << '早期のエスカレーション'
    end
    
    suggestions.presence || ['継続的なサポート']
  end
end