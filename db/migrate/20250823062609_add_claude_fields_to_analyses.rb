class AddClaudeFieldsToAnalyses < ActiveRecord::Migration[7.1]
  def change
    add_column :analyses, :hidden_needs, :jsonb
    add_column :analyses, :escalation_reason, :text
    add_column :analyses, :analyzed_at, :datetime
  end
end
