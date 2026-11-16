# frozen_string_literal: true

require "test_helper"

class ProjectsControllerTest < ActionController::TestCase
  tests ProjectsController

  def setup
    setup_controller_test
  end

  test "actions" do
    grant_policy("projects_show")
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

  test "show references the folder the project belongs to" do
    @user.users_policies.create!(policy: "projects_show")
    project = projects(:one)
    folder = folders(:one)
    project.create_folders_item!(folder: folder)

    get :show, params: { id: project.id }

    assert_response :success
    assert_includes @response.body, folder.name
    assert_includes @response.body, folders_show_path(folder.id)
  end

  test "show links the folder change modal" do
    @user.users_policies.create!(policy: "projects_show")
    project = projects(:one)
    item = project.create_folders_item!(folder: folders(:one))

    get :show, params: { id: project.id }

    assert_response :success
    assert_includes @response.body, "Sposta in altra cartella"
    assert_includes @response.body, ERB::Util.html_escape(folders_actions_path(type: "manage-resource", item_id: item.id, resource_id: project.id, resource_type: "Project"))
  end

  test "show_attachment" do
    @user.users_policies.create!(policy: "projects_show")
    project = projects(:one)
    attachment = project.projects_attachments.create!(title: "Test Attachment", date: Date.today)
    file_path = Rails.root.join("test/fixtures/files/test.txt")
    file = Rack::Test::UploadedFile.new(file_path, "text/plain")
    attachment.file.attach(io: file, filename: file.original_filename, content_type: file.content_type)

    get :show_attachment, params: { id: attachment.id }
    assert_response :success

    get :show_attachment, params: { id: -1 }
    assert_response :not_found
  end

  test "show_log" do
    grant_policy("projects_show")
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

  test "create_action with invalid data marks fields and opens their section" do
    grant_policy("projects_create")
    post :create_action, params: { code: "PRJ-INVALID", name: "", year: "" }

    assert_response :success
    assert_select "input#name.is-invalid + .invalid-feedback"
    assert_select "input#year.is-invalid + .invalid-feedback"
    assert_select "#formProjectAccordionArchive.collapse.show"
    assert_select ".alert-danger li", minimum: 2
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

  test "pin_log_action" do
    project = projects(:one)
    log = project.projects_logs.create!(title: "Test Log", date: Date.today, content: "Log content", user_id: users(:one).id)
    matilda_controller_endpoint(:post, :pin_log_action,
      params: { id: project.id, log_id: log.id },
      policy: "projects_manage_logs",
      title: "Metti in evidenza nota",
      feedback: "Nota in evidenza"
    )

    log.reload
    assert log.pinned?
  end

  test "unpin_log_action" do
    project = projects(:one)
    log = project.projects_logs.create!(title: "Test Log", date: Date.today, content: "Log content", user_id: users(:one).id, pinned: true)
    matilda_controller_endpoint(:post, :unpin_log_action,
      params: { id: project.id, log_id: log.id },
      policy: "projects_manage_logs",
      title: "Rimuovi nota dalle evidenze",
      feedback: "Nota non più in evidenza"
    )

    log.reload
    assert_not log.pinned?
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

  # BULK ACTIONS
  ##############################################################################

  test "bulk_action archives the selected projects and offers an undo" do
    grant_policy("projects_archive", "projects_unarchive")
    one = projects(:one)
    two = Project.create!(code: "two", name: "Project Two", year: 2024)

    post :bulk_action, params: { operation: "archive", ids: [ one.id, two.id ] }

    assert_response :success
    assert_includes @response.body, "<h3 class=\"fs-5 mb-1\">2 progetti archiviati</h3>"
    assert one.reload.archived
    assert two.reload.archived
    assert_includes @response.body, "operation=unarchive"
  end

  test "bulk_action undo restores the same projects without a further undo" do
    grant_policy("projects_archive", "projects_unarchive")
    one = projects(:one)
    two = Project.create!(code: "two", name: "Project Two", year: 2024)
    one.update!(archived: true)
    two.update!(archived: true)

    post :bulk_action, params: { operation: "unarchive", ids: [ one.id, two.id ], undo: 1 }

    assert_response :success
    assert_includes @response.body, "2 progetti ripristinati"
    assert_not one.reload.archived
    assert_not two.reload.archived
    assert_not_includes @response.body, "operation=archive"
  end

  test "bulk_action requires the policy of the operation" do
    grant_policy("projects_unarchive", "folders_manage_resources")
    project = projects(:one)

    post :bulk_action, params: { operation: "archive", ids: [ project.id ] }

    assert_redirected_to root_path
    assert_not project.reload.archived
  end

  test "bulk_action rejects unknown operations" do
    grant_policy("projects_archive")
    project = projects(:one)

    post :bulk_action, params: { operation: "destroy", ids: [ project.id ] }

    assert_response :success
    assert_includes @response.body, "id=\"action-modal-title\">Errore</h3>"
    assert Project.exists?(project.id)
  end

  test "bulk_action ignores projects outside the membership limit" do
    grant_policy("projects_archive", "only_data_projects_as_member")
    mine = projects(:one)
    mine.projects_members.create!(user: @user, role: "member")
    other = Project.create!(code: "other", name: "Other Project", year: 2024)

    post :bulk_action, params: { operation: "archive", ids: [ mine.id, other.id ] }

    assert_response :success
    assert_includes @response.body, "1 progetto archiviato"
    assert mine.reload.archived
    assert_not other.reload.archived
  end

  test "bulk_action without the reverse policy offers no undo" do
    grant_policy("projects_archive")

    post :bulk_action, params: { operation: "archive", ids: [ projects(:one).id ] }

    assert_response :success
    assert projects(:one).reload.archived
    assert_not_includes @response.body, "operation=unarchive"
  end

  test "bulk_action moves projects to a folder and the undo puts them back" do
    grant_policy("folders_manage_resources")
    folder = folders(:one)
    previous_folder = Folder.create!(name: "Previous Folder")
    one = projects(:one)
    two = Project.create!(code: "two", name: "Project Two", year: 2024)
    two.create_folders_item!(folder: previous_folder)

    post :bulk_action, params: { operation: "move", ids: [ one.id, two.id ], folder_id: folder.id }

    assert_response :success
    assert_includes @response.body, "2 progetti spostati"
    assert_equal folder.id, one.reload.folders_item.folder_id
    assert_equal folder.id, two.reload.folders_item.folder_id

    # Replay the undo the feedback offers
    undo_href = CGI.unescapeHTML(@response.body[%r{action="([^"]*bulk-action[^"]*)"}, 1])
    undo_params = Rack::Utils.parse_nested_query(URI.parse(undo_href).query)
    assert_equal "1", undo_params["undo"]

    post :bulk_action, params: undo_params

    assert_response :success
    assert_nil one.reload.folders_item
    assert_equal previous_folder.id, two.reload.folders_item.folder_id
  end

  test "bulk_action move ignores unknown folders and hidden projects" do
    grant_policy("folders_manage_resources", "only_data_projects_as_member")
    mine = projects(:one)
    mine.projects_members.create!(user: @user, role: "member")
    other = Project.create!(code: "other", name: "Other Project", year: 2024)

    post :bulk_action, params: { operation: "move", ids: [ mine.id ], folder_id: 99_999 }
    assert_includes @response.body, "Nessun progetto spostato"
    assert_nil mine.reload.folders_item

    post :bulk_action, params: { operation: "move", ids: [ mine.id, other.id ], folder_id: folders(:one).id }
    assert_includes @response.body, "1 progetto spostato"
    assert_equal folders(:one).id, mine.reload.folders_item.folder_id
    assert_nil other.reload.folders_item
  end

  test "bulk-move modal counts and submits only the visible selected projects" do
    grant_policy("projects_show", "only_data_projects_as_member")
    mine = projects(:one)
    mine.projects_members.create!(user: @user, role: "member")
    other = Project.create!(code: "other", name: "Other Project", year: 2024)

    get :actions, params: { type: "bulk-move", ids: [ mine.id, other.id ] }

    assert_response :success
    assert_includes @response.body, "id=\"action-modal-title\">Sposta in cartella</h3>"
    assert_includes @response.body, "1 progetto selezionato."
    assert_not_includes @response.body, mine.name
    assert_select "input[type=hidden][name='ids[]'][value='#{mine.id}']"
    assert_select "input[type=hidden][name='ids[]'][value='#{other.id}']", 0
  end

  test "bulk-archive asks for confirmation before archiving the visible selected projects" do
    grant_policy("projects_show", "only_data_projects_as_member")
    mine = projects(:one)
    mine.projects_members.create!(user: @user, role: "member")
    other = Project.create!(code: "other", name: "Other Project", year: 2024)

    get :actions, params: { type: "bulk-archive", ids: [ mine.id, other.id ] }

    assert_response :success
    assert_includes @response.body, "id=\"action-modal-title\">Archivia progetti</h3>"
    assert_includes @response.body, "1 progetto verrà archiviato"
    assert_select "form[action='#{projects_bulk_action_path}'] input[name=operation][value=archive]"
    assert_select "input[type=hidden][name='ids[]'][value='#{mine.id}']"
    assert_select "input[type=hidden][name='ids[]'][value='#{other.id}']", 0
    assert_not mine.reload.archived
  end

  test "index renders the selection mode for bulk actions" do
    grant_policy("projects_index", "projects_archive")

    get :index

    assert_response :success
    assert_includes @response.body, "data-controller=\"bulk-select\""
    assert_includes @response.body, "aria-label=\"Seleziona #{projects(:one).name}\""
  end
end
