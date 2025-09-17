# frozen_string_literal: true

require "test_helper"

class ProjectsControllerTest < ActionController::TestCase
  tests ProjectsController

  def setup
    @user = users(:one)
    cookies.encrypted[:user_id] = @user.id

    Rails.cache.clear
    ActionMailer::Base.deliveries.clear
  end

  # Test for GET index with valid policy
  test "should get index with valid policy" do
    @user.users_policies.create!(policy: "projects_index")
    get :index
    assert_response :success
    assert_not_nil @controller.instance_variable_get(:@projects)
    assert_not_nil @controller.instance_variable_get(:@projects_preferred)
  end

  # Test for GET index without valid policy
  test "should not get index without valid policy" do
    get :index
    assert_redirected_to root_path
  end

  # Test for GET show with valid policy
  test "should get show with valid policy" do
    @user.users_policies.create!(policy: "projects_show")
    project = projects(:one)
    get :show, params: { id: project.id }
    assert_response :success
    assert_not_nil @controller.instance_variable_get(:@project)
  end

  # Test for GET show without valid policy
  test "should not get show without valid policy" do
    project = projects(:one)
    get :show, params: { id: project.id }
    assert_redirected_to root_path
  end

  # Test for GET show_attachment with valid attachment id
  test "should get show_attachment with valid attachment id" do
    project = projects(:one)
    attachment = project.projects_attachments.create!(title: "Test Attachment", date: Date.today)
    attachment.file.attach(io: StringIO.new("Test content"), filename: "test.txt", content_type: "text/plain")

    get :show_attachment, params: { id: attachment.id }
    assert_response :success
    assert_equal "Test content", @response.body
  end

  # Test for GET show_attachment with invalid attachment id
  test "should not get show_attachment with invalid attachment id" do
    assert_raises ActiveRecord::RecordNotFound do
      get :show_attachment, params: { id: -1 }
    end
  end

  # Test for GET show_log with valid log id
  test "should get show_log with valid log id" do
    project = projects(:one)
    log = project.projects_logs.create!(title: "Test Log", date: Date.today, content: "Log content", user_id: users(:one).id)

    get :show_log, params: { id: log.id }
    assert_response :success
    assert_not_nil @controller.instance_variable_get(:@log)
  end

  # Test for GET show_log with invalid log id
  test "should not get show_log with invalid log id" do
    assert_raises ActiveRecord::RecordNotFound do
      get :show_log, params: { id: -1 }
    end
  end

  # Tests for GET actions with type create
  test "should get actions create" do
    get :actions, params: { type: "create" }
    assert_response :success
    assert_match(/Nuovo progetto/, @response.body)
  end

  # Tests for GET actions with type edit and valid id
  test "should get actions edit with valid id" do
    project = projects(:one)
    get :actions, params: { type: "edit", id: project.id }
    assert_response :success
    assert_match(/Modifica progetto/, @response.body)
  end

  # Tests for GET actions with type edit and invalid id
  test "should get actions edit with invalid id" do
    assert_raises ActiveRecord::RecordNotFound do
      get :actions, params: { type: "edit", id: 9999 }
    end
  end

  # Tests for GET actions with type archive and valid id
  test "should get actions archive with valid id" do
    project = projects(:one)
    get :actions, params: { type: "archive", id: project.id }
    assert_response :success
    assert_match(/Archivia progetto/, @response.body)
  end

  # Tests for GET actions with type archive and invalid id
  test "should get actions archive with invalid id" do
    assert_raises ActiveRecord::RecordNotFound do
      get :actions, params: { type: "archive", id: 9999 }
    end
  end

  # Tests for GET actions with type unarchive and valid id
  test "should get actions unarchive with valid id" do
    project = projects(:one)
    get :actions, params: { type: "unarchive", id: project.id }
    assert_response :success
    assert_match(/Ri-attiva progetto/, @response.body)
  end

  # Tests for GET actions with type unarchive and invalid id
  test "should get actions unarchive with invalid id" do
    assert_raises ActiveRecord::RecordNotFound do
      get :actions, params: { type: "unarchive", id: 9999 }
    end
  end

  # Tests for GET actions with type destroy and valid id
  test "should get actions destroy with valid id" do
    get :actions, params: { type: "destroy", id: projects(:one).id }
    assert_response :success
    assert_match(/Elimina progetto/, @response.body)
  end

  # Tests for GET actions with type destroy and invalid id
  test "should get actions destroy with invalid id" do
    assert_raises ActiveRecord::RecordNotFound do
      get :actions, params: { type: "destroy", id: 9999 }
    end
  end

  # Tests for GET actions with type add-procedure and valid id
  test "should get actions add-procedure with valid id" do
    project = projects(:one)
    get :actions, params: { type: "add-procedure", id: project.id }
    assert_response :success
    assert_match(/Aggiungi board/, @response.body)
  end

  # Tests for GET actions with type add-procedure and invalid id
  test "should get actions add-procedure with invalid id" do
    assert_raises ActiveRecord::RecordNotFound do
      get :actions, params: { type: "add-procedure", id: 9999 }
    end
  end

  # Tests for GET actions with type add-member and valid id
  test "should get actions add-member with valid id" do
    project = projects(:one)
    get :actions, params: { type: "add-member", id: project.id }
    assert_response :success
    assert_match(/Aggiungi partecipante/, @response.body)
  end

  # Tests for GET actions with type add-member and invalid id
  test "should get actions add-member with invalid id" do
    assert_raises ActiveRecord::RecordNotFound do
      get :actions, params: { type: "add-member", id: 9999 }
    end
  end

  # Tests for GET actions with type edit-member and valid id
  test "should get actions edit-member with valid id" do
    project = projects(:one)
    project.projects_members.create!(user: @user, role: "member")
    get :actions, params: { type: "edit-member", id: project.id, member_id: @user.id }
    assert_response :success
    assert_match(/Modifica partecipante/, @response.body)
  end

  # Tests for GET actions with type edit-member and invalid id
  test "should get actions edit-member with invalid id" do
    assert_raises ActiveRecord::RecordNotFound do
      get :actions, params: { type: "edit-member", id: 9999, member_id: 9999 }
    end
  end

  # Tests for GET actions with type remove-member and valid id
  test "should get actions remove-member with valid id" do
    project = projects(:one)
    project.projects_members.create!(user: @user, role: "member")
    get :actions, params: { type: "remove-member", id: project.id, member_id: @user.id }
    assert_response :success
    assert_match(/Rimuovi partecipante/, @response.body)
  end

  # Tests for GET actions with type remove-member and invalid id
  test "should get actions remove-member with invalid id" do
    assert_raises ActiveRecord::RecordNotFound do
      get :actions, params: { type: "remove-member", id: 9999, member_id: 9999 }
    end
  end

  # Tests for GET actions with type add-log and valid id
  test "should get actions add-log with valid id" do
    project = projects(:one)
    get :actions, params: { type: "add-log", id: project.id }
    assert_response :success
    assert_match(/Aggiungi nota/, @response.body)
  end

  # Tests for GET actions with type add-log and invalid id
  test "should get actions add-log with invalid id" do
    assert_raises ActiveRecord::RecordNotFound do
      get :actions, params: { type: "add-log", id: 9999 }
    end
  end

  # Tests for GET actions with type show-log and valid id
  test "should get actions show-log with valid id" do
    project = projects(:one)
    log = project.projects_logs.create!(title: "Test Log", date: Date.today, content: "Log content", user_id: users(:one).id)

    get :actions, params: { type: "show-log", id: project.id, log_id: log.id }
    assert_response :success
    assert_match(/Visualizza nota/, @response.body)
  end

  # Tests for GET actions with type show-log and invalid id
  test "should get actions show-log with invalid id" do
    assert_raises ActiveRecord::RecordNotFound do
      get :actions, params: { type: "show-log", id: 9999, log_id: 9999 }
    end
  end

  # Tests for GET actions with type share-log and valid id
  test "should get actions share-log with valid id" do
    project = projects(:one)
    log = project.projects_logs.create!(title: "Test Log", date: Date.today, content: "Log content", user_id: users(:one).id)

    get :actions, params: { type: "share-log", id: project.id, log_id: log.id }
    assert_response :success
    assert_match(/Condividi nota/, @response.body)
  end

  # Tests for GET actions with type share-log and invalid id
  test "should get actions share-log with invalid id" do
    assert_raises ActiveRecord::RecordNotFound do
      get :actions, params: { type: "share-log", id: 9999, log_id: 9999 }
    end
  end

  # Tests for GET actions with type unshare-log and valid id
  test "should get actions unshare-log with valid id" do
    project = projects(:one)
    log = project.projects_logs.create!(title: "Test Log", date: Date.today, content: "Log content", user_id: users(:one).id)

    get :actions, params: { type: "unshare-log", id: project.id, log_id: log.id }
    assert_response :success
    assert_match(/Annulla condivisione nota/, @response.body)
  end

  # Tests for GET actions with type unshare-log and invalid id
  test "should get actions unshare-log with invalid id" do
    assert_raises ActiveRecord::RecordNotFound do
      get :actions, params: { type: "unshare-log", id: 9999, log_id: 9999 }
    end
  end

  # Tests for GET actions with type edit-log and valid id
  test "should get actions edit-log with valid id" do
    project = projects(:one)
    log = project.projects_logs.create!(title: "Test Log", date: Date.today, content: "Log content", user_id: users(:one).id)

    get :actions, params: { type: "edit-log", id: project.id, log_id: log.id }
    assert_response :success
    assert_match(/Modifica nota/, @response.body)
  end

  # Tests for GET actions with type edit-log and invalid id
  test "should get actions edit-log with invalid id" do
    assert_raises ActiveRecord::RecordNotFound do
      get :actions, params: { type: "edit-log", id: 9999, log_id: 9999 }
    end
  end

  # Tests for GET actions with type remove-log and valid id
  test "should get actions remove-log with valid id" do
    project = projects(:one)
    log = project.projects_logs.create!(title: "Test Log", date: Date.today, content: "Log content", user_id: users(:one).id)

    get :actions, params: { type: "remove-log", id: project.id, log_id: log.id }
    assert_response :success
    assert_match(/Rimuovi nota/, @response.body)
  end

  # Tests for GET actions with type remove-log and invalid id
  test "should get actions remove-log with invalid id" do
    assert_raises ActiveRecord::RecordNotFound do
      get :actions, params: { type: "remove-log", id: 9999, log_id: 9999 }
    end
  end

  # Tests for GET actions with type add-attachment and valid id
  test "should get actions add-attachment with valid id" do
    project = projects(:one)
    get :actions, params: { type: "add-attachment", id: project.id }
    assert_response :success
    assert_match(/Aggiungi allegato/, @response.body)
  end

  # Tests for GET actions with type add-attachment and invalid id
  test "should get actions add-attachment with invalid id" do
    assert_raises ActiveRecord::RecordNotFound do
      get :actions, params: { type: "add-attachment", id: 9999 }
    end
  end

  # Tests for GET actions with type edit-attachment and valid id
  test "should get actions edit-attachment with valid id" do
    project = projects(:one)
    attachment = project.projects_attachments.create!(title: "Test Attachment", date: Date.today)
    attachment.file.attach(io: StringIO.new("Test content"), filename: "test.txt", content_type: "text/plain")

    get :actions, params: { type: "edit-attachment", id: project.id, attachment_id: attachment.id }
    assert_response :success
    assert_match(/Modifica allegato/, @response.body)
  end

  # Tests for GET actions with type edit-attachment and invalid id
  test "should get actions edit-attachment with invalid id" do
    assert_raises ActiveRecord::RecordNotFound do
      get :actions, params: { type: "edit-attachment", id: 9999, attachment_id: 9999 }
    end
  end

  # Tests for GET actions with type remove-attachment and valid id
  test "should get actions remove-attachment with valid id" do
    project = projects(:one)
    attachment = project.projects_attachments.create!(title: "Test Attachment", date: Date.today)
    attachment.file.attach(io: StringIO.new("Test content"), filename: "test.txt", content_type: "text/plain")

    get :actions, params: { type: "remove-attachment", id: project.id, attachment_id: attachment.id }
    assert_response :success
    assert_match(/Rimuovi allegato/, @response.body)
  end

  # Tests for GET actions with type remove-attachment and invalid id
  test "should get actions remove-attachment with invalid id" do
    assert_raises ActiveRecord::RecordNotFound do
      get :actions, params: { type: "remove-attachment", id: 9999, attachment_id: 9999 }
    end
  end

  # Test for GET actions con tipo non valido
  test "should get actions with invalid type" do
    get :actions, params: { type: "invalid_type" }
    assert_response :success
    assert_match(/Si è verificato un errore/, @response.body)
  end

  # Tests for POST create_action with valid policy
  test "should post create_action with valid policy" do
    @user.users_policies.create!(policy: "projects_create")
    post :create_action, params: { code: "PRJ-TEST", name: "Test Project", year: 2024 }
    assert_response :success
    assert_match(/Progetto creato/, @response.body)
  end

  # Tests for POST create_action without valid policy
  test "should not post create_action without valid policy" do
    post :create_action, params: { code: "PRJ-TEST", name: "Test Project", year: 2024 }
    assert_redirected_to root_path
  end

  # Tests for POST edit_action with valid id and valid policy
  test "should post edit_action with valid id and valid policy" do
    @user.users_policies.create!(policy: "projects_edit")
    project = projects(:one)
    post :edit_action, params: { id: project.id, code: project.code, name: "Updated Project", year: project.year }
    assert_response :success
    assert_match(/Progetto aggiornato/, @response.body)
  end

  # Tests for POST edit_action without valid policy
  test "should not post edit_action without valid policy" do
    project = projects(:one)
    post :edit_action, params: { id: project.id, code: project.code, name: "Updated Project", year: project.year }
    assert_redirected_to root_path
  end

  # Tests for POST archive_action with valid id and valid policy
  test "should post archive_action with valid id and valid policy" do
    @user.users_policies.create!(policy: "projects_archive")
    project = projects(:one)
    post :archive_action, params: { id: project.id }
    assert_response :success
    assert_match(/Progetto archiviato/, @response.body)
  end

  # Tests for POST archive_action without valid policy
  test "should not post archive_action without valid policy" do
    project = projects(:one)
    post :archive_action, params: { id: project.id }
    assert_redirected_to root_path
  end

  # Tests for POST unarchive_action with valid id and valid policy
  test "should post unarchive_action with valid id and valid policy" do
    @user.users_policies.create!(policy: "projects_unarchive")
    project = projects(:one)
    post :unarchive_action, params: { id: project.id }
    assert_response :success
    assert_match(/Progetto ri-attivato/, @response.body)
  end

  # Tests for POST unarchive_action without valid policy
  test "should not post unarchive_action without valid policy" do
    project = projects(:one)
    post :unarchive_action, params: { id: project.id }
    assert_redirected_to root_path
  end

  # Tests for POST destroy_action with valid id and valid policy
  test "should post destroy_action with valid id and valid policy" do
    @user.users_policies.create!(policy: "projects_destroy")
    project = projects(:one)
    post :destroy_action, params: { id: project.id }
    assert_response :success
    assert_match(/Progetto eliminato/, @response.body)
  end

  # Tests for POST destroy_action without valid policy
  test "should not post destroy_action without valid policy" do
    project = projects(:one)
    post :destroy_action, params: { id: project.id }
    assert_redirected_to root_path
  end

  # Tests for POST add_procedure_action with valid id and valid policy
  test "should post add_procedure_action with valid id and valid policy" do
    @user.users_policies.create!(policy: "projects_manage_procedures")
    project = projects(:one)
    post :add_procedure_action, params: { id: project.id, procedure_id: procedures(:model_one).id }
    assert_response :success
    assert_match(/Board aggiunto al progetto/, @response.body)
  end

  # Tests for POST add_procedure_action without valid policy
  test "should not post add_procedure_action without valid policy" do
    project = projects(:one)
    post :add_procedure_action, params: { id: project.id, procedure_id: procedures(:model_one).id }
    assert_redirected_to root_path
  end

  # Tests for POST add_procedures_item_action with valid id and valid policy
  test "should post add_procedures_item_action with valid id and valid policy" do
    @user.users_policies.create!(policy: "projects_manage_procedures_items")
    project = projects(:one)
    post :add_procedures_item_action, params: { id: project.id, procedure_id: procedures(:model_one).id }
    assert_response :success
    assert_match(/Progetto aggiunto alla board/, @response.body)
  end

  # Tests for POST add_procedures_item_action without valid policy
  test "should not post add_procedures_item_action without valid policy" do
    project = projects(:one)
    post :add_procedures_item_action, params: { id: project.id, procedure_id: procedures(:model_one).id }
    assert_redirected_to root_path
  end

  # Tests for POST add_member_action with valid id and valid policy
  test "should post add_member_action with valid id and valid policy" do
    @user.users_policies.create!(policy: "projects_manage_members")
    project = projects(:one)
    post :add_member_action, params: { id: project.id, user_id: users(:one).id, role: "sample" }
    assert_response :success
    assert_match(/Partecipante aggiunto/, @response.body)
  end

  # Tests for POST add_member_action without valid policy
  test "should not post add_member_action without valid policy" do
    project = projects(:one)
    post :add_member_action, params: { id: project.id, user_id: users(:one).id, role: "sample" }
    assert_redirected_to root_path
  end
end
