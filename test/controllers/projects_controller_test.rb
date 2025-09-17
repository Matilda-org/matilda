# frozen_string_literal: true

require "test_helper"

class ProjectsControllerTest < ActionController::TestCase
  tests ProjectsController

  def setup
    setup_controller_test
  end

  test "actions" do
    project = projects(:one)
    member = project.projects_members.create!(user: @user, role: "member")
    log = project.projects_logs.create!(title: "Test Log", date: Date.today, content: "Log content", user_id: users(:one).id)
    attachment = project.projects_attachments.create!(title: "Test Attachment", date: Date.today)

    matilda_controller_action("create", "Nuovo progetto")
    matilda_controller_action("edit", "Modifica progetto", project.id)
    matilda_controller_action("archive", "Archivia progetto", project.id)
    matilda_controller_action("unarchive", "Ri-attiva progetto", project.id)
    matilda_controller_action("destroy", "Elimina progetto", project.id)
    matilda_controller_action("add-procedure", "Aggiungi board", project.id)
    matilda_controller_action("add-member", "Aggiungi partecipante", project.id)
    matilda_controller_action("edit-member", "Modifica partecipante", project.id, { member_id: member.id })
    matilda_controller_action("remove-member", "Rimuovi partecipante", project.id, { member_id: member.id })
    matilda_controller_action("add-log", "Aggiungi nota", project.id)
    matilda_controller_action("show-log", "Visualizza nota", project.id, { log_id: log.id })
    matilda_controller_action("share-log", "Condividi nota", project.id, { log_id: log.id })
    matilda_controller_action("unshare-log", "Annulla condivisione nota", project.id, { log_id: log.id })
    matilda_controller_action("edit-log", "Modifica nota", project.id, { log_id: log.id })
    matilda_controller_action("remove-log", "Rimuovi nota", project.id, { log_id: log.id })
    matilda_controller_action("add-attachment", "Aggiungi allegato", project.id)
    matilda_controller_action("edit-attachment", "Modifica allegato", project.id, { attachment_id: attachment.id })
    matilda_controller_action("remove-attachment", "Rimuovi allegato", project.id, { attachment_id: attachment.id })

    matilda_controller_action_invalid
  end

  test "index" do
    matilda_controller_endpoint(:get, :index,
      policy: "projects_index"
    )
  end

  test "show" do
    project = projects(:one)
    matilda_controller_endpoint(:get, :show,
      params: { id: project.id },
      policy: "projects_show"
    )
  end

  test "show_attachment" do
    project = projects(:one)
    attachment = project.projects_attachments.create!(title: "Test Attachment", date: Date.today)
    file_path = Rails.root.join("test/fixtures/files/test.txt")
    file = Rack::Test::UploadedFile.new(file_path, "text/plain")
    attachment.file.attach(io: file, filename: file.original_filename, content_type: file.content_type)

    get :show_attachment, params: { id: attachment.id }
    assert_response :success

    assert_raises ActiveRecord::RecordNotFound do
      get :show_attachment, params: { id: -1 }
    end
  end

  test "show_log" do
    project = projects(:one)
    log = project.projects_logs.create!(title: "Test Log", date: Date.today, content: "Log content", user_id: users(:one).id)
    matilda_controller_endpoint(:get, :show_log,
      params: { id: log.id }
    )
  end

  test "create_action" do
    matilda_controller_endpoint(:post, :create_action,
      params: { code: "PRJ-TEST", name: "Test Project", year: 2024 },
      policy: "projects_create",
      title: "Nuovo progetto",
      feedback: "Progetto creato"
    )

    project = Project.find_by(code: "PRJ-TEST")
    assert_not_nil project
    assert_equal "Test Project", project.name
    assert_equal 2024, project.year
  end

  test "edit_action" do
    project = projects(:one)
    matilda_controller_endpoint(:post, :edit_action,
      params: { id: project.id, code: project.code, name: "Updated Project", year: project.year },
      policy: "projects_edit",
      title: "Modifica progetto",
      feedback: "Progetto aggiornato"
    )

    project.reload
    assert_equal "Updated Project", project.name
  end

  test "archive_action" do
    project = projects(:one)
    assert_not project.archived

    matilda_controller_endpoint(:post, :archive_action,
      params: { id: project.id },
      policy: "projects_archive",
      title: "Archivia progetto",
      feedback: "Progetto archiviato"
    )

    project.reload
    assert project.archived
  end

  test "unarchive_action" do
    project = projects(:one)
    project.update!(archived: true)
    assert project.archived

    matilda_controller_endpoint(:post, :unarchive_action,
      params: { id: project.id },
      policy: "projects_unarchive",
      title: "Ri-attiva progetto",
      feedback: "Progetto ri-attivato"
    )

    project.reload
    assert_not project.archived
  end

  test "destroy_action" do
    project = projects(:one)
    matilda_controller_endpoint(:post, :destroy_action,
      params: { id: project.id },
      policy: "projects_destroy",
      title: "Elimina progetto",
      feedback: "Progetto eliminato"
    )

    assert_not Project.exists?(project.id)
  end

  test "add_procedure_action" do
    project = projects(:one)
    procedure = procedures(:two)
    matilda_controller_endpoint(:post, :add_procedure_action,
      params: { id: project.id, procedure_id: procedure.id },
      policy: "projects_manage_procedures",
      title: "Aggiungi board",
      feedback: "Board aggiunto al progetto"
    )

    project.reload
    assert project.procedures.first
    assert_equal project.procedures.first.name, "#{procedure.name} (clone)"
  end

  test "add_procedures_item_action" do
    project = projects(:one)
    procedure = procedures(:three)
    matilda_controller_endpoint(:post, :add_procedures_item_action,
      params: { id: project.id, procedure_id: procedure.id },
      policy: "projects_manage_procedures_items",
      title: "Aggiungi ad una board",
      feedback: "Progetto aggiunto alla board"
    )

    project.reload
    assert project.procedures_items.first
    assert_equal project.procedures_items.first.title, procedure.procedures_items.first.title
  end

  test "add_member_action" do
    project = projects(:one)
    new_user = users(:one)
    matilda_controller_endpoint(:post, :add_member_action,
      params: { id: project.id, user_id: new_user.id, role: "member" },
      policy: "projects_manage_members",
      title: "Aggiungi partecipante",
      feedback: "Partecipante aggiunto"
    )

    project.reload
    assert project.projects_members.where(user_id: new_user.id).exists?
  end

  test "edit_member_action" do
    project = projects(:one)
    member = project.projects_members.create!(user: users(:one), role: "member")
    matilda_controller_endpoint(:post, :edit_member_action,
      params: { id: project.id, member_id: member.id, role: "Admin" },
      policy: "projects_manage_members",
      title: "Modifica partecipante",
      feedback: "Partecipante modificato"
    )

    member.reload
    assert_equal "Admin", member.role
  end

  test "remove_member_action" do
    project = projects(:one)
    member = project.projects_members.create!(user: users(:one), role: "member")
    matilda_controller_endpoint(:post, :remove_member_action,
      params: { id: project.id, member_id: member.id },
      policy: "projects_manage_members",
      title: "Rimuovi partecipante",
      feedback: "Partecipante rimosso"
    )

    assert_not project.projects_members.where(id: member.id).exists?
  end

  test "add_log_action" do
    project = projects(:one)
    matilda_controller_endpoint(:post, :add_log_action,
      params: { id: project.id, title: "New Log", date: Date.today, content: "Log content" },
      policy: "projects_manage_logs",
      title: "Aggiungi nota",
      feedback: "Nota aggiunta"
    )

    project.reload
    assert project.projects_logs.where(title: "New Log").exists?
  end

  test "edit_log_action" do
    project = projects(:one)
    log = project.projects_logs.create!(title: "Test Log", date: Date.today, content: "Log content", user_id: users(:one).id)
    matilda_controller_endpoint(:post, :edit_log_action,
      params: { id: project.id, log_id: log.id, title: "Updated Log", date: log.date, content: log.content },
      policy: "projects_manage_logs",
      title: "Modifica nota",
      feedback: "Nota modificata"
    )

    log.reload
    assert_equal "Updated Log", log.title
  end

  test "share_log_action" do
    project = projects(:one)
    log = project.projects_logs.create!(title: "Test Log", date: Date.today, content: "Log content", user_id: users(:one).id)
    matilda_controller_endpoint(:post, :share_log_action,
      params: { id: project.id, log_id: log.id },
      policy: "projects_manage_logs",
      title: "Condividi nota",
      feedback: "Nota pubblicata"
    )

    log.reload
    assert_not_nil log.share_code
  end

  test "unshare_log_action" do
    project = projects(:one)
    log = project.projects_logs.create!(title: "Test Log", date: Date.today, content: "Log content", user_id: users(:one).id, share_code: SecureRandom.hex(10))
    matilda_controller_endpoint(:post, :unshare_log_action,
      params: { id: project.id, log_id: log.id },
      policy: "projects_manage_logs",
      title: "Annulla condivisione nota",
      feedback: "Nota non più pubblicata"
    )

    log.reload
    assert_nil log.share_code
  end

  test "remove_log_action" do
    project = projects(:one)
    log = project.projects_logs.create!(title: "Test Log", date: Date.today, content: "Log content", user_id: users(:one).id)
    matilda_controller_endpoint(:post, :remove_log_action,
      params: { id: project.id, log_id: log.id },
      policy: "projects_manage_logs",
      title: "Rimuovi nota",
      feedback: "Nota rimossa"
    )

    assert_not project.projects_logs.where(id: log.id).exists?
  end

  test "add_attachment_action" do
    project = projects(:one)
    file_path = Rails.root.join("test/fixtures/files/test.txt")
    file = Rack::Test::UploadedFile.new(file_path, "text/plain")

    matilda_controller_endpoint(:post, :add_attachment_action,
      params: { id: project.id, title: "New Attachment", date: Date.today, file: file },
      policy: "projects_manage_attachments",
      title: "Aggiungi allegato",
      feedback: "Allegato aggiunto"
    )

    project.reload
    assert project.projects_attachments.where(title: "New Attachment").exists?
  end

  test "edit_attachment_action" do
    project = projects(:one)
    attachment = project.projects_attachments.create!(title: "Test Attachment", date: Date.today)
    file_path = Rails.root.join("test/fixtures/files/test.txt")
    file = Rack::Test::UploadedFile.new(file_path, "text/plain")
    attachment.file.attach(io: file, filename: file.original_filename, content_type: file.content_type)

    matilda_controller_endpoint(:post, :edit_attachment_action,
      params: { id: project.id, attachment_id: attachment.id, title: "Updated Attachment" },
      policy: "projects_manage_attachments",
      title: "Modifica allegato",
      feedback: "Allegato modificato"
    )

    attachment.reload
    assert_equal "Updated Attachment", attachment.title
  end

  test "remove_attachment_action" do
    project = projects(:one)
    attachment = project.projects_attachments.create!(title: "Test Attachment", date: Date.today)
    matilda_controller_endpoint(:post, :remove_attachment_action,
      params: { id: project.id, attachment_id: attachment.id },
      policy: "projects_manage_attachments",
      title: "Rimuovi allegato",
      feedback: "Allegato rimosso"
    )

    assert_not project.projects_attachments.where(id: attachment.id).exists?
  end
end
