# frozen_string_literal: true

# データベースクエリ数を検証するカスタムマッチャー
RSpec::Matchers.define :make_database_queries do |options = {}|
  supports_block_expectations

  match do |block|
    @query_count = count_queries(&block)
    
    if options[:count]
      @query_count == options[:count]
    elsif options[:maximum]
      @query_count <= options[:maximum]
    elsif options[:minimum]
      @query_count >= options[:minimum]
    else
      false
    end
  end

  failure_message do
    if options[:count]
      "expected #{options[:count]} queries, but got #{@query_count}"
    elsif options[:maximum]
      "expected at most #{options[:maximum]} queries, but got #{@query_count}"
    elsif options[:minimum]
      "expected at least #{options[:minimum]} queries, but got #{@query_count}"
    else
      "must specify :count, :maximum, or :minimum option"
    end
  end

  def count_queries(&block)
    count = 0
    counter = ->(*, payload) do
      count += 1 unless payload[:name] == 'SCHEMA' || payload[:sql]&.match?(/^(BEGIN|COMMIT|ROLLBACK)/)
    end

    ActiveSupport::Notifications.subscribed(counter, 'sql.active_record', &block)
    count
  end
end