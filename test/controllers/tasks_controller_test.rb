# frozen_string_literal: true

require "test_helper"

class TasksControllerTest < ActionController::TestCase
  tests TasksController

  def setup
    setup_controller_test
  end

  test "actions" do
    grant_policy("tasks_show")
    task = tasks(:one)

    matilda_controller_action("create", "Nuovo task")
    matilda_controller_action("edit", "Modifica task", task.id)
    matilda_controller_action("destroy", "Elimina task", task.id)
    matilda_controller_action("complete", "Completa task", task.id)
    matilda_controller_action("postpone", "Rimanda task", task.id)
    matilda_controller_action("uncomplete", "Attiva task", task.id)
    matilda_controller_action("add-track", "Aggiungi tempo di lavoro", task.id)
    matilda_controller_action_invalid
  end

  test "create form offers AI filling when the assistant is configured" do
    grant_policy("tasks_show")
    Setting.set("vectorsearch_openai_key", "sk-test")

    get :actions, params: { type: "create" }

    assert_response :success
    assert_includes @response.body, "Compila dal testo"
  end

  test "index" do
    matilda_controller_endpoint(:get, :index,
      policy: "tasks_index"
    )
  end

  test "a failed comment keeps the draft and shows the error" do
    grant_policy("tasks_comment")
    task = tasks(:one)
    task.tasks_comments.create!(content: "Mine", user_id: @user.id)

    post :create_comment_action, params: { id: task.id, content: " " }

    assert_response :unprocessable_entity
    assert_select "div[role=alert]"
    assert_select "a.c-comment__delete", 1
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

  test "create_action with invalid data marks the title" do
    grant_policy("tasks_create")
    post :create_action, params: { title: "" }

    assert_response :success
    assert_select "input#title.is-invalid + .invalid-feedback"
    assert_select "select#user_id"
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

  test "move_action reschedules a task to the dropped day (calendar)" do
    @user.users_policies.create!(policy: "tasks_edit")
    task = tasks(:one)
    target = Date.today + 3

    post :move_action, params: { id: task.id, mode: "calendar", deadline: target.strftime("%Y-%m-%d") }

    assert_response :success
    assert_equal target, task.reload.deadline
  end

  test "move_action reassigns a task to the dropped user (people)" do
    @user.users_policies.create!(policy: "tasks_edit")
    task = tasks(:one)

    post :move_action, params: { id: task.id, mode: "people", assignee_id: users(:two).id }

    assert_response :success
    assert_equal users(:two).id, task.reload.user_id
  end

  test "move_action unassigns a task when dropped on the unassigned column" do
    @user.users_policies.create!(policy: "tasks_edit")
    task = tasks(:one)
    task.update!(user_id: users(:two).id)

    post :move_action, params: { id: task.id, mode: "people", assignee_id: "" }

    assert_response :success
    assert_nil task.reload.user_id
  end

  test "move_action requires the tasks_edit policy" do
    task = tasks(:one)

    post :move_action, params: { id: task.id, mode: "calendar", deadline: Date.today.strftime("%Y-%m-%d") }

    assert_redirected_to root_path
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

  test "add_track_action" do
    task = tasks(:one)
    before = task.time_spent
    matilda_controller_endpoint(:post, :add_track_action,
      params: { id: task.id, date: Date.today.strftime("%Y-%m-%d"), duration: 3600 },
      policy: "tasks_track",
      title: "Aggiungi tempo",
      feedback: "Tempo aggiunto"
    )

    task.reload
    assert_equal before + 3600, task.time_spent
    track = task.tasks_tracks.where.not(end_at: nil).order(:created_at).last
    assert_not_nil track
    assert_equal 3600, track.time_spent
  end

  test "add_track_action with invalid duration re-renders the form" do
    task = tasks(:one)
    @user.users_policies.create!(policy: "tasks_track")
    before = task.time_spent
    post :add_track_action, params: { id: task.id, date: Date.today.strftime("%Y-%m-%d"), duration: 0 }

    assert_response :unprocessable_content
    task.reload
    assert_equal before, task.time_spent
  end

  test "tracks index" do
    task = tasks(:one)
    task.tasks_tracks.create!(start_at: 1.hour.ago, end_at: Time.now, time_spent: 3600, user: @user)

    matilda_controller_endpoint(:get, :tracks, policy: "tasks_index")
  end

  test "tracks index filtered by task" do
    task = tasks(:one)
    task.tasks_tracks.create!(start_at: 1.hour.ago, end_at: Time.now, time_spent: 3600, user: @user)
    @user.users_policies.create!(policy: "tasks_index")

    get :tracks, params: { task_id: task.id }
    assert_response :success
    assert_select "table"
  end

  test "tracks index filtered by date" do
    task = tasks(:one)
    task.tasks_tracks.create!(start_at: Time.current.change(hour: 10), end_at: Time.current.change(hour: 11), time_spent: 3600, user: @user)
    task.tasks_tracks.create!(start_at: 3.days.ago.change(hour: 10), end_at: 3.days.ago.change(hour: 11), time_spent: 3600, user: @user)
    @user.users_policies.create!(policy: "tasks_index")

    get :tracks, params: { date: Date.current.iso8601 }
    assert_response :success
    # solo il track odierno deve comparire
    assert_select "tbody tr", 1
    assert_select "input#date[value=?]", Date.current.iso8601
  end

  test "tracks index ignores invalid date" do
    task = tasks(:one)
    task.tasks_tracks.create!(start_at: 1.hour.ago, end_at: Time.now, time_spent: 3600, user: @user)
    @user.users_policies.create!(policy: "tasks_index")

    get :tracks, params: { date: "not-a-date" }
    assert_response :success
    # data non valida ignorata: il track resta visibile e il campo è vuoto
    assert_select "tbody tr", 1
    assert_select "input#date[value=?]", ""
  end

  test "destroy_track_action rolls back task time" do
    task = tasks(:one)
    before = task.time_spent
    track = task.tasks_tracks.create!(start_at: 1.hour.ago, end_at: Time.now, time_spent: 3600, user: @user)
    task.update_columns(time_spent: before + 3600)

    matilda_controller_endpoint(:post, :destroy_track_action,
      params: { track_id: track.id },
      policy: "tasks_track",
      redirect: tasks_tracks_path
    )

    assert_not Tasks::Track.exists?(track.id)
    assert_equal before, task.reload.time_spent
  end

  test "update_track_date_action sposta il tracking nel futuro" do
    task = tasks(:one)
    start_at = 2.days.ago.change(hour: 9)
    track = task.tasks_tracks.create!(start_at: start_at, end_at: start_at + 3600, ping_at: start_at, time_spent: 3600, user: @user)
    new_date = Date.current + 3.days

    matilda_controller_endpoint(:post, :update_track_date_action,
      params: { track_id: track.id, date: new_date.iso8601 },
      policy: "tasks_track",
      redirect: tasks_tracks_path
    )

    assert_equal new_date, track.reload.start_at.to_date
    assert_equal 3600, track.time_spent
  end

  test "update_track_date_action ignora una data non valida" do
    task = tasks(:one)
    start_at = 2.days.ago.change(hour: 9)
    track = task.tasks_tracks.create!(start_at: start_at, end_at: start_at + 3600, ping_at: start_at, time_spent: 3600, user: @user)

    matilda_controller_endpoint(:post, :update_track_date_action,
      params: { track_id: track.id, date: "not-a-date" },
      policy: "tasks_track",
      redirect: tasks_tracks_path
    )

    assert_equal start_at.to_date, track.reload.start_at.to_date
  end

  test "add_track_action with a custom duration" do
    task = tasks(:one)
    before = task.time_spent
    matilda_controller_endpoint(:post, :add_track_action,
      params: { id: task.id, date: Date.today.strftime("%Y-%m-%d"), duration: "custom", hours: "1", minutes: "30" },
      policy: "tasks_track",
      title: "Aggiungi tempo",
      feedback: "Tempo aggiunto"
    )

    task.reload
    assert_equal before + 90.minutes.to_i, task.time_spent
    assert_equal 90.minutes.to_i, task.tasks_tracks.order(:created_at).last.time_spent
  end

  test "add_track_action with an invalid custom duration shows an inline error" do
    task = tasks(:one)
    @user.users_policies.create!(policy: "tasks_track")
    before = task.time_spent

    [ { hours: "0", minutes: "0" }, { hours: "1", minutes: "75" }, { hours: "24", minutes: "30" }, { hours: "abc", minutes: "" } ].each do |custom|
      post :add_track_action, params: { id: task.id, date: Date.today.strftime("%Y-%m-%d"), duration: "custom" }.merge(custom)

      assert_response :unprocessable_content
      assert_includes response.body, "Inserisci una durata valida"
      assert_includes response.body, "is-invalid"
    end

    assert_equal before, task.reload.time_spent
  end

  test "calendar overdue column lists unfinished overdue tasks of the visible filter" do
    grant_policy("tasks_index")
    week_start = Date.today.at_beginning_of_week
    overdue = Task.create!(title: "Overdue open", user: @user, deadline: week_start - 3, accepted: true)
    Task.create!(title: "Overdue done", user: @user, deadline: week_start - 3, accepted: true, completed: true, completed_at: Time.current)
    Task.create!(title: "Overdue other user", user: users(:two), deadline: week_start - 3, accepted: true)

    get :index, params: { user_id: @user.id, date_start: week_start, date_end: week_start + 6 }

    assert_response :success
    assert_select "turbo-frame#tasks-calendar-status-overdue" do
      assert_select "turbo-frame[data-item='#{overdue.id}']"
      assert_select "*", text: /Overdue done/, count: 0
      assert_select "*", text: /Overdue other user/, count: 0
    end
  end

  test "move_action from the overdue column re-renders it without the moved task" do
    grant_policy("tasks_edit")
    week_start = Date.today.at_beginning_of_week
    task = Task.create!(title: "Late task", user: @user, deadline: week_start - 2, accepted: true)

    post :move_action, params: { id: task.id, mode: "calendar", deadline: week_start.strftime("%Y-%m-%d"), date_start: week_start, date_end: week_start + 6 }

    assert_response :success
    assert_equal week_start, task.reload.deadline
    assert_includes response.body, %(target="tasks-calendar-status-overdue")
    assert_includes response.body, %(target="tasks-calendar-status-#{week_start.strftime('%Y-%m-%d')}")
    overdue_stream = response.body[/<turbo-stream action="replace" target="tasks-calendar-status-overdue">.*?<\/turbo-stream>/m]
    assert_not_includes overdue_stream, %(data-item="#{task.id}")
  end

  # update_field_action (inline editing on the task detail)

  def update_field(task, field, value)
    post :update_field_action, params: { id: task.id, field: field, value: value, frame: "abc123" }
  end

  test "update_field_action updates the title and re-renders its frame" do
    grant_policy("tasks_edit")
    task = tasks(:one)

    update_field(task, "title", "Renamed")

    assert_response :success
    assert_equal "Renamed", task.reload.title
    assert_includes response.body, %(id="task_#{task.id}_title_abc123")
    assert_includes response.body, "Modifica titolo: Renamed"
  end

  test "update_field_action updates and clears the deadline" do
    grant_policy("tasks_edit")
    task = tasks(:one)
    target = Date.new(2026, 8, 25)

    update_field(task, "deadline", target.iso8601)
    assert_response :success
    assert_equal target, task.reload.deadline
    assert_includes response.body, "Modifica scadenza: 25/08/2026"

    update_field(task, "deadline", "")
    assert_response :success
    assert_nil task.reload.deadline
  end

  test "update_field_action assigns and unassigns the task" do
    grant_policy("tasks_edit")
    task = tasks(:one)

    assert_difference -> { Notification.where(user_id: users(:two).id, typology: :task_assigned).count } do
      update_field(task, "user_id", users(:two).id)
    end
    assert_response :success
    assert_equal users(:two).id, task.reload.user_id

    update_field(task, "user_id", "")
    assert_response :success
    assert_nil task.reload.user_id
  end

  test "update_field_action updates the time estimate" do
    grant_policy("tasks_edit")
    task = tasks(:one)

    update_field(task, "time_estimate", 7200)

    assert_response :success
    assert_equal 7200, task.reload.time_estimate
  end

  test "update_field_action keeps the input open with the error on invalid values" do
    grant_policy("tasks_edit")
    task = tasks(:one)

    update_field(task, "title", "")
    assert_response :unprocessable_entity
    assert_equal "Task one", task.reload.title
    assert_includes response.body, "is-invalid"
    assert_includes response.body, "invalid-feedback"
    assert_includes response.body, %(data-task-inline-edit-editing-value="true")
    assert_includes response.body, "Non può essere lasciato in bianco"

    { "deadline" => "not-a-date", "user_id" => "999999", "time_estimate" => "42" }.each do |field, value|
      update_field(task, field, value)
      assert_response :unprocessable_entity
      assert_includes response.body, "invalid-feedback"
      assert_includes response.body, %(value="#{value}") if field == "deadline"
    end
    assert_equal tasks(:one).time_estimate, task.reload.time_estimate
  end

  test "update_field_action rejects fields outside the whitelist" do
    grant_policy("tasks_edit")
    task = tasks(:one)

    update_field(task, "completed", "1")
    assert_response :bad_request
    assert_not task.reload.completed

    post :update_field_action, params: { id: task.id, field: "title", value: "X", frame: "<script>" }
    assert_response :bad_request
  end

  test "update_field_action requires the tasks_edit policy" do
    task = tasks(:one)

    update_field(task, "title", "Forbidden")

    assert_redirected_to root_path
    assert_equal "Task one", task.reload.title
  end

  test "update_field_action respects the members-only scoping" do
    grant_policy("tasks_edit", "only_data_projects_as_member")
    task = tasks(:one)
    task.update_columns(project_id: projects(:one).id, user_id: nil)

    update_field(task, "title", "Out of scope")

    assert_redirected_to tasks_path
    assert_equal "Task one", task.reload.title
  end

  test "task detail renders inline editors only with tasks_edit" do
    grant_policy("tasks_show")
    task = tasks(:one)

    get :actions, params: { type: "show", id: task.id }
    assert_not_includes response.body, "c-inline-edit__trigger"

    Rails.cache.clear
    grant_policy("tasks_edit")
    get :actions, params: { type: "show", id: task.id }
    %w[titolo scadenza assegnatario tempo\ stimato].each do |label|
      assert_includes response.body, "aria-label=\"Modifica #{label}:"
    end

    get :show, params: { id: task.id }
    assert_response :success
    assert_includes response.body, "aria-label=\"Modifica titolo: Task one\""
  end
end
