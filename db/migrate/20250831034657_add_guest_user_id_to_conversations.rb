class AddGuestUserIdToConversations < ActiveRecord::Migration[7.1]
  def change
    add_column :conversations, :guest_user_id, :string
    add_index :conversations, :guest_user_id
  end
end
