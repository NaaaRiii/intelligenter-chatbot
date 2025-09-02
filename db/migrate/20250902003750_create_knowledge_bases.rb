# frozen_string_literal: true

class CreateKnowledgeBases < ActiveRecord::Migration[7.1]
  def change
    create_table :knowledge_bases do |t|
      t.references :conversation, foreign_key: true, null: true
      t.string :pattern_type, null: false
      t.jsonb :content, null: false, default: {}
      t.text :summary
      t.integer :success_score, default: 0
      t.jsonb :metadata, default: {}
      t.string :tags, array: true, default: []
      
      t.timestamps
    end
    
    add_index :knowledge_bases, :pattern_type
    add_index :knowledge_bases, :success_score
    add_index :knowledge_bases, :tags, using: 'gin'
    add_index :knowledge_bases, :content, using: 'gin'
    add_index :knowledge_bases, :metadata, using: 'gin'
  end
end