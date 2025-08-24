class AddDetailedFieldsToAnalyses < ActiveRecord::Migration[7.1]
  def change
    # hidden_needsとanalyzed_atは既に存在するのでスキップ
    add_column :analyses, :customer_sentiment, :string unless column_exists?(:analyses, :customer_sentiment)
    add_column :analyses, :escalation_reasons, :text unless column_exists?(:analyses, :escalation_reasons)
    
    # インデックスを追加
    add_index :analyses, :customer_sentiment unless index_exists?(:analyses, :customer_sentiment)
    add_index :analyses, :analyzed_at unless index_exists?(:analyses, :analyzed_at)
    add_index :analyses, :hidden_needs, using: :gin unless index_exists?(:analyses, :hidden_needs)
  end
end
