class CreateAnalyses < ActiveRecord::Migration[7.1]
  def change
    create_table :analyses do |t|
      t.references :conversation, null: false, foreign_key: true
      t.string :analysis_type
      t.jsonb :analysis_data
      t.string :priority_level
      t.string :sentiment
      t.boolean :escalated
      t.datetime :escalated_at

      t.timestamps
    end
  end
end
