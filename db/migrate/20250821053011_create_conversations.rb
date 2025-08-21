class CreateConversations < ActiveRecord::Migration[7.1]
  def change
    create_table :conversations do |t|
      t.references :user, null: false, foreign_key: true
      t.string :session_id
      t.datetime :ended_at

      t.timestamps
    end
    add_index :conversations, :session_id, unique: true
  end
end
