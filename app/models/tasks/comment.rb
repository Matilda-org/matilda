class Tasks::Comment < ApplicationRecord
  include Cachable

  # VALIDATIONS
  ############################################################

  validates :content, presence: true

  # RELATIONS
  ############################################################

  belongs_to :user, optional: true
  belongs_to :task

  # HOOKS
  ############################################################

  after_create_commit :update_task_unresolved
  after_destroy_commit :update_task_unresolved_on_destroy

  private

  def update_task_unresolved
    return unless task.user_id.present?

    last_comment_by_assignee = user_id == task.user_id
    task.update_column(:unresolved, !last_comment_by_assignee)
  end

  def update_task_unresolved_on_destroy
    return if !task || task.destroyed?
    return unless task.user_id.present?

    last_comment = task.tasks_comments.order(created_at: :asc).last
    if last_comment.nil?
      task.update_column(:unresolved, false)
    else
      task.update_column(:unresolved, last_comment.user_id != task.user_id)
    end
  end
end
