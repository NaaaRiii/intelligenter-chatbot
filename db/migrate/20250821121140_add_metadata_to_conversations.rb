class AddMetadataToConversations < ActiveRecord::Migration[7.1]
  def change
    add_column :conversations, :metadata, :jsonb
  end
end
