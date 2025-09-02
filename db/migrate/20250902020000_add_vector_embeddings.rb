# frozen_string_literal: true

class AddVectorEmbeddings < ActiveRecord::Migration[7.1]
  def change
    # pgvector拡張を有効化
    enable_extension 'vector' unless extension_enabled?('vector')
    
    # messagesテーブルにベクトル埋め込みカラムを追加（配列型として）
    add_column :messages, :embedding, :float, array: true
    
    # knowledge_basesテーブルにベクトル埋め込みカラムを追加（配列型として）
    add_column :knowledge_bases, :embedding, :float, array: true
    
    # 通常のGINインデックスを使用（pgvectorが利用できない環境でも動作）
    add_index :messages, :embedding, using: :gin, name: 'index_messages_on_embedding'
    add_index :knowledge_bases, :embedding, using: :gin, name: 'index_knowledge_bases_on_embedding'
  end
end