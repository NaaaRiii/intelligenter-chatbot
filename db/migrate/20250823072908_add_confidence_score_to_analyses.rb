class AddConfidenceScoreToAnalyses < ActiveRecord::Migration[7.1]
  def change
    add_column :analyses, :confidence_score, :float
  end
end
