class CleanupPresentations < ActiveRecord::Migration[8.0]
  def change
    drop_table :presentations_actions
    drop_table :presentations_notes
    drop_table :presentations_pages
    drop_table :presentations

    ActiveStorage::Attachment.where(record_type: "Presentation").destroy_all
  end
end
