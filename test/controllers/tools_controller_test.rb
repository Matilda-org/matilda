# frozen_string_literal: true

require "test_helper"

class ToolsControllerTest < ActionController::TestCase
  tests ToolsController

  def setup
    setup_controller_test
  end

  test "index" do
    matilda_controller_endpoint(:get, :index,
      policy: "tools"
    )
  end

  test "projects_without_procedures" do
    matilda_controller_endpoint(:get, :projects_without_procedures,
      policy: "tools"
    )
  end

  test "project_risks" do
    matilda_controller_endpoint(:get, :project_risks,
      policy: "tools"
    )
  end

  test "projects_tasks_tracking" do
    matilda_controller_endpoint(:get, :projects_tasks_tracking,
      policy: "tools"
    )
  end

  test "projects_tasks_tracking counts time spent on the end date of the range" do
    @user.users_policies.create!(policy: "tools")
    project = projects(:one)
    task = project.tasks.create!(title: "Test Task")
    date_start = Date.today.at_beginning_of_month
    date_end = Date.today.at_end_of_month
    task.tasks_tracks.create!(start_at: date_end.to_time.change(hour: 17), end_at: date_end.to_time.change(hour: 18), time_spent: 3600)

    get :projects_tasks_tracking, params: { date_start: date_start, date_end: date_end }

    assert_response :success
    assert @response.body.include?("01h 00m")
  end

  test "projects_tasks_tracking filters by project_id, procedure_id and procedure_status_id" do
    @user.users_policies.create!(policy: "tools")
    project = projects(:one)
    procedure = project.procedures.create!(name: "Procedure", resources_type: "tasks")
    status = procedure.procedures_statuses.create!(title: "Status")
    task = project.tasks.create!(title: "Test Task")
    status.procedures_items.create!(procedure: procedure, resource: task)
    task.tasks_tracks.create!(start_at: Time.now, end_at: Time.now, time_spent: 1800)

    get :projects_tasks_tracking, params: { project_id: project.id, procedure_id: procedure.id, procedure_status_id: status.id }

    assert_response :success
    assert @response.body.include?("00h 30m")
  end

  test "projects_tasks_tracking filters by project_id and procedure_id" do
    @user.users_policies.create!(policy: "tools")
    project = projects(:one)
    procedure = project.procedures.create!(name: "Procedure", resources_type: "tasks")
    status = procedure.procedures_statuses.create!(title: "Status")
    task = project.tasks.create!(title: "Test Task")
    status.procedures_items.create!(procedure: procedure, resource: task)
    task.tasks_tracks.create!(start_at: Time.now, end_at: Time.now, time_spent: 1800)

    get :projects_tasks_tracking, params: { project_id: project.id, procedure_id: procedure.id }

    assert_response :success
    assert @response.body.include?("00h 30m")
  end

  test "projects_tasks_tracking filters by project_id" do
    @user.users_policies.create!(policy: "tools")
    project = projects(:one)
    procedure = project.procedures.create!(name: "Procedure", resources_type: "tasks")
    status = procedure.procedures_statuses.create!(title: "Status")
    task = project.tasks.create!(title: "Test Task")
    status.procedures_items.create!(procedure: procedure, resource: task)
    task.tasks_tracks.create!(start_at: Time.now, end_at: Time.now, time_spent: 1800)

    get :projects_tasks_tracking, params: { project_id: project.id }

    assert_response :success
    assert @response.body.include?("00h 30m")
  end

  test "projects_tasks_tracking filters by user_id" do
    @user.users_policies.create!(policy: "tools")
    project = projects(:one)
    other_user = users(:two)
    task = project.tasks.create!(title: "Test Task")
    task.tasks_tracks.create!(start_at: Time.now, end_at: Time.now, time_spent: 1800, user_id: @user.id)
    task.tasks_tracks.create!(start_at: Time.now, end_at: Time.now, time_spent: 900, user_id: other_user.id)

    get :projects_tasks_tracking, params: { user_id: @user.id }

    assert_response :success
    assert @response.body.include?("00h 30m")
    assert_not @response.body.include?("00h 15m")
  end

  test "projects_tasks_tracking with print param renders the print layout" do
    @user.users_policies.create!(policy: "tools")

    get :projects_tasks_tracking, params: { print: "1" }

    assert_response :success
    assert @response.body.include?("TOTALE")
  end
end
