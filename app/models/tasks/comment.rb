class Tasks::Comment < ApplicationRecord
  include Cachable

  # VALIDATIONS
  ############################################################

  validates :content, presence: true

  # RELATIONS
  ############################################################

  belongs_to :user, optional: true
  # counter_cache keeps tasks.tasks_comments_count in sync without touching
  # the task updated_at
  # explicit column: the default derived from the demodulized class name would
  # be comments_count, while the has_many side reads tasks_comments_count
  belongs_to :task, counter_cache: :tasks_comments_count

  # HOOKS
  ############################################################

  # Non-commit hooks on purpose: they run inside the surrounding transaction,
  # so the denormalized task columns roll back with the comment and the sync
  # also works under transactional test fixtures (commit hooks never fire there).
  after_create :sync_task_comment_state
  after_destroy :sync_task_comment_state

  private

  # Keeps the task denormalized comment data aligned with the last comment:
  # who wrote it (shown on the task card) and whether it still awaits a reply
  # from the assignee (used by the crew loop).
  def sync_task_comment_state
    return if task.nil? || task.destroyed?

    last_comment = task.tasks_comments.order(created_at: :asc, id: :asc).last

    attributes = { last_comment_user_id: last_comment&.user_id }
    # unresolved only makes sense on assigned tasks
    if task.user_id.present?
      attributes[:unresolved] = last_comment.present? && last_comment.user_id != task.user_id
    end

    # update_columns on purpose: commenting must not bump the task updated_at
    task.update_columns(attributes)
  end
end
