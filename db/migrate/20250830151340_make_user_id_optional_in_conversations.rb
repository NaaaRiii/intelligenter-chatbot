class MakeUserIdOptionalInConversations < ActiveRecord::Migration[7.1]
  def change
    change_column_null :conversations, :user_id, true
  end
end
