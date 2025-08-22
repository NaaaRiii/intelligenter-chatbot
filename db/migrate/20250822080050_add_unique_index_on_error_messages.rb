class AddUniqueIndexOnErrorMessages < ActiveRecord::Migration[7.1]
  def up
    # assistantロール かつ metadata->>'error' = 'true' のとき、
    # 同一conversation内で metadata->>'original_message_id' が一意になるよう制約
    execute <<~SQL
      CREATE UNIQUE INDEX IF NOT EXISTS index_messages_unique_error_per_original
      ON messages (conversation_id, ((metadata ->> 'original_message_id')))
      WHERE role = 'assistant' AND (metadata ->> 'error') = 'true';
    SQL
  end

  def down
    execute <<~SQL
      DROP INDEX IF EXISTS index_messages_unique_error_per_original;
    SQL
  end
end
