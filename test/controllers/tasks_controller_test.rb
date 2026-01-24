# frozen_string_literal: true

require "test_helper"

class TasksControllerTest < ActionController::TestCase
  tests TasksController

  def setup
    setup_controller_test
  end

  test "actions" do
    task = tasks(:one)

    matilda_controller_action("create", "Nuovo task")
    matilda_controller_action("edit", "Modifica task", task.id)
    matilda_controller_action("destroy", "Elimina task", task.id)
    matilda_controller_action("complete", "Completa task", task.id)
    matilda_controller_action("postpone", "Rimanda task", task.id)
    matilda_controller_action("uncomplete", "Attiva task", task.id)
    matilda_controller_action_invalid
  end

  test "index" do
    matilda_controller_endpoint(:get, :index,
      policy: "tasks_index"
    )
  end

  test "show" do
    task = tasks(:one)
    matilda_controller_endpoint(:get, :show,
      params: { id: task.id },
      policy: "tasks_show"
    )
  end

  test "create_action" do
    matilda_controller_endpoint(:post, :create_action,
      params: { title: "New Task" },
      policy: "tasks_create",
      title: "Nuovo task",
      feedback: "Task creato"
    )

    assert Task.exists?(title: "New Task")
  end

  test "edit_action" do
    task = tasks(:one)
    matilda_controller_endpoint(:post, :edit_action,
      params: { id: task.id, title: "Updated Task" },
      policy: "tasks_edit",
      title: "Modifica task",
      feedback: "Task aggiornato"
    )

    task.reload
    assert_equal "Updated Task", task.title
  end

  test "destroy_action" do
    task = tasks(:one)
    matilda_controller_endpoint(:post, :destroy_action,
      params: { id: task.id },
      policy: "tasks_destroy",
      title: "Elimina task",
      feedback: "Task eliminato"
    )

    assert_not Task.exists?(id: task.id)
  end

  test "complete_action" do
    task = tasks(:one)
    matilda_controller_endpoint(:post, :complete_action,
      params: { id: task.id },
      policy: "tasks_complete",
      title: "Completa task",
      feedback: "Task completato"
    )

    task.reload
    assert task.completed
  end

  test "postpone_action" do
    task = tasks(:one)
    matilda_controller_endpoint(:post, :postpone_action,
      params: { id: task.id },
      policy: "tasks_edit",
      title: "Rimanda task",
      feedback: "Task rimandato"
    )

    task.reload
    assert_not_nil task.deadline
    assert_equal 1.day.from_now.to_date, task.deadline.to_date
  end

  test "uncomplete_action" do
    task = tasks(:one)
    task.update(completed: true, completed_at: Time.now)
    assert task.completed
    matilda_controller_endpoint(:post, :uncomplete_action,
      params: { id: task.id },
      policy: "tasks_uncomplete",
      title: "Attiva task",
      feedback: "Task attivato",
    )

    task.reload
    assert_not task.completed
  end

  test "start_track_action" do
    task = tasks(:one)
    matilda_controller_endpoint(:post, :start_track_action,
      params: { id: task.id },
      policy: "tasks_track"
    )

    task.reload
    assert task.tasks_tracks.exists?(end_at: nil)
  end

  test "ping_track_action" do
    task = tasks(:one)
    track = task.tasks_tracks.create!(start_at: 1.minutes.ago, user: @user)
    assert track.ping_at <= 1.minutes.ago
    matilda_controller_endpoint(:post, :ping_track_action,
      params: { id: task.id, track_id: track.id },
      policy: "tasks_track"
    )

    track.reload
    assert track.ping_at > 1.minutes.ago
  end

  test "end_track_action" do
    task = tasks(:one)
    track = task.tasks_tracks.create!(start_at: 1.minutes.ago, user: @user)
    assert_nil track.end_at
    matilda_controller_endpoint(:post, :end_track_action,
      params: { id: task.id, track_id: track.id },
      policy: "tasks_track"
    )

    track.reload
    assert_not_nil track.end_at
  end
end
