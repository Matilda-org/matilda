require "test_helper"

class Tasks::CommentTest < ActiveSupport::TestCase
  test "creating a comment marks the task unresolved when the commenter is not the assignee" do
    assignee = users(:one)
    commenter = users(:two)
    task = Task.create!(title: "Task", user_id: assignee.id)

    task.tasks_comments.create!(content: "Comment", user_id: commenter.id)

    assert task.reload.unresolved
  end

  test "creating a comment marks the task resolved when the commenter is the assignee" do
    assignee = users(:one)
    task = Task.create!(title: "Task", user_id: assignee.id, unresolved: true)

    task.tasks_comments.create!(content: "Comment", user_id: assignee.id)

    assert_not task.reload.unresolved
  end

  test "creating a comment does not change unresolved when the task has no assignee" do
    task = Task.create!(title: "Task", user_id: nil)

    task.tasks_comments.create!(content: "Comment", user_id: users(:two).id)

    assert_not task.reload.unresolved
  end

  test "destroying the last remaining comment resolves the task" do
    assignee = users(:one)
    task = Task.create!(title: "Task", user_id: assignee.id)
    comment = task.tasks_comments.create!(content: "Comment", user_id: users(:two).id)
    assert task.reload.unresolved

    comment.destroy

    assert_not task.reload.unresolved
  end

  test "destroying a comment recalculates unresolved from the remaining last comment" do
    assignee = users(:one)
    other = users(:two)
    task = Task.create!(title: "Task", user_id: assignee.id)
    task.tasks_comments.create!(content: "First, by assignee", user_id: assignee.id, created_at: 1.hour.ago)
    last_comment = task.tasks_comments.create!(content: "Second, by other", user_id: other.id)
    assert task.reload.unresolved

    last_comment.destroy

    assert_not task.reload.unresolved
  end

  test "comments keep the task counter cache and last comment author in sync" do
    assignee = users(:one)
    other = users(:two)
    task = Task.create!(title: "Task", user_id: assignee.id)

    task.tasks_comments.create!(content: "First, by assignee", user_id: assignee.id, created_at: 1.hour.ago)
    last_comment = task.tasks_comments.create!(content: "Second, by other", user_id: other.id)

    task.reload
    assert_equal 2, task.tasks_comments_count
    assert_equal other.id, task.last_comment_user_id

    last_comment.destroy

    task.reload
    assert_equal 1, task.tasks_comments_count
    assert_equal assignee.id, task.last_comment_user_id
  end

  test "the last comment author is cleared when no comment is left" do
    task = Task.create!(title: "Task", user_id: users(:one).id)
    comment = task.tasks_comments.create!(content: "Comment", user_id: users(:two).id)

    comment.destroy

    task.reload
    assert_equal 0, task.tasks_comments_count
    assert_nil task.last_comment_user_id
  end

  test "the last comment author is tracked on tasks without an assignee" do
    task = Task.create!(title: "Task", user_id: nil)

    task.tasks_comments.create!(content: "Comment", user_id: users(:two).id)

    assert_equal users(:two).id, task.reload.last_comment_user_id
  end
end
