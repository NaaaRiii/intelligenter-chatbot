# frozen_string_literal: true

class CreateResolutionPaths < ActiveRecord::Migration[7.1]
  def change
    create_table :resolution_paths do |t|
      t.string :problem_type
      t.text :solution
      t.integer :steps_count
      t.integer :resolution_time
      t.boolean :successful, default: false
      t.jsonb :key_actions, default: []
      t.jsonb :metadata, default: {}

      t.timestamps
    end

    add_index :resolution_paths, :problem_type
    add_index :resolution_paths, :successful
    add_index :resolution_paths, :steps_count
    add_index :resolution_paths, :key_actions, using: :gin
    add_index :resolution_paths, :metadata, using: :gin
  end
end