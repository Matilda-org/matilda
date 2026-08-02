class AddCommentsStatsToTasks < ActiveRecord::Migration[8.0]
  def up
    # denormalized data shown on every task card: total comments + last author,
    # so rendering a list of cards costs no extra query per card
    add_column :tasks, :tasks_comments_count, :integer, default: 0, null: false
    add_column :tasks, :last_comment_user_id, :integer

    Task.reset_column_information
    Task.find_each do |task|
      Task.reset_counters(task.id, :tasks_comments)
      last_comment = task.tasks_comments.order(created_at: :asc, id: :asc).last
      task.update_column(:last_comment_user_id, last_comment&.user_id)
    end
  end

  def down
    remove_column :tasks, :tasks_comments_count
    remove_column :tasks, :last_comment_user_id
  end
end
