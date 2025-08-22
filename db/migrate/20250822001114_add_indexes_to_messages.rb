# frozen_string_literal: true

class AddIndexesToMessages < ActiveRecord::Migration[7.1]
  def change
    # conversation_idとcreated_atの複合インデックス（時系列取得の高速化）
    add_index :messages, %i[conversation_id created_at], name: 'index_messages_on_conversation_and_created'
    
    # roleに対するインデックス（ロール別フィルタリング用）
    add_index :messages, :role
    
    # metadataのGINインデックス（JSONB検索の高速化）
    add_index :messages, :metadata, using: :gin, if_not_exists: true
    
    # created_atの単体インデックス（時間範囲検索用）
    add_index :messages, :created_at
    
    # conversation_idとroleの複合インデックス（会話内のロール別取得用）
    add_index :messages, %i[conversation_id role], name: 'index_messages_on_conversation_and_role'
  end
end
