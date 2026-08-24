class RemoveContentFromCommunicationsLogs < ActiveRecord::Migration[8.0]
  def change
    # notes moved to action_text (rich text) to hold long formatted content
    remove_column :communications_logs, :content, :text
  end
end
