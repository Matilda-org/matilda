require "test_helper"

class VectorsearchTools::ActionsToolTest < ActiveSupport::TestCase
  setup do
    Rails.cache.clear
    @user = users(:one)
    @project = Project.create!(code: "PRJ", name: "Project", year: 2026)
  end

  def tool
    @tool ||= VectorsearchTools::ActionsTool.new(@user)
  end

  # runs the proposal the tool just stored, as the "Conferma" button does
  def confirm_last_proposal
    Vectorsearch.new(@user.id).confirm_action(tool.proposals.last[:id])
  end

  test "a proposal writes nothing until it is confirmed" do
    @user.update_policies([ "tasks_create" ])

    assert_no_difference "Task.count" do
      assert_match "Azione proposta", tool.tasks_create({ user_id: users(:two).id, title: "Call the client", deadline: "2026-10-20" })
    end
    assert_equal "crea il task «Call the client» assegnato a Bianchi Luisa, scadenza 20/10/2026", tool.proposals.last[:label]

    assert_difference "Task.count", 1 do
      assert confirm_last_proposal
    end
    assert_equal users(:two).id, Task.last.user_id
  end

  test "a confirmed proposal runs only once" do
    @user.update_policies([ "tasks_create" ])
    tool.tasks_create({ user_id: @user.id, title: "Once" })
    vectorsearch = Vectorsearch.new(@user.id)

    assert vectorsearch.confirm_action(tool.proposals.last[:id])
    assert_not vectorsearch.confirm_action(tool.proposals.last[:id])
    assert_equal 1, Task.where(title: "Once").count
  end

  test "a user cannot confirm another user's proposal" do
    @user.update_policies([ "tasks_create" ])
    tool.tasks_create({ user_id: @user.id, title: "Not yours" })

    assert_not Vectorsearch.new(users(:two).id).confirm_action(tool.proposals.last[:id])
    assert_not Task.exists?(title: "Not yours")
  end

  test "nothing is proposed without the policy" do
    assert_match "Non hai i permessi", tool.tasks_create({ user_id: @user.id, title: "Denied" })
    assert_empty tool.proposals
  end

  test "invalid data is reported to the model instead of proposed" do
    @user.update_policies([ "tasks_create" ])

    assert_match "Scadenza non valida", tool.tasks_create({ user_id: @user.id, title: "Bad date", deadline: "domani" })
    assert_match "array JSON", tool.tasks_create({ user_id: @user.id, title: "Bad list", checklist: "one, two" })
    assert_empty tool.proposals
  end

  test "checks run again on confirm" do
    @user.update_policies([ "tasks_complete" ])
    task = Task.create!(title: "To close", project: @project)
    tool.tasks_complete({ task_id: task.id })
    task.update!(completed: true)

    confirm_last_proposal

    assert_equal "Il task è già completato", Vectorsearch.new(@user.id).messages.last[:content]
  end

  test "member-restricted user cannot comment tasks of other projects" do
    @user.update_policies([ "tasks_comment", "only_data_projects_as_member" ])
    task = Task.create!(title: "Other", project: @project)

    assert_equal "Task non trovato", tool.tasks_comment({ task_id: task.id, content: "hi" })
  end

  test "comment is written as the confirming user" do
    @user.update_policies([ "tasks_comment" ])
    task = Task.create!(title: "Discuss", project: @project)
    tool.tasks_comment({ task_id: task.id, content: "Done on staging" })

    confirm_last_proposal

    assert_equal [ "Done on staging", @user.id ], task.tasks_comments.pick(:content, :user_id)
  end

  test "crm actions need the crm policy" do
    communication = Communication.create!(contact: contacts(:one), campaign: campaigns(:one))

    assert_match "Non hai i permessi", tool.crm_communication_log_create({ communication_id: communication.id, content: "note" })
  end

  test "crm note is added and follow-up needs a sent communication" do
    @user.update_policies([ "crm" ])
    communication = Communication.create!(contact: contacts(:one), campaign: campaigns(:one))
    assert_match "solo su comunicazioni inviate", tool.crm_follow_up_create({ communication_id: communication.id })

    tool.crm_communication_log_create({ communication_id: communication.id, content: "Asked for a quote" })
    confirm_last_proposal
    assert_includes communication.communications_logs.last.content.to_plain_text, "Asked for a quote"

    communication.update!(status: :sent, sent_date: Date.today)
    tool.crm_follow_up_create({ communication_id: communication.id })
    confirm_last_proposal
    assert_equal 1, communication.reload.follow_ups_count
  end

  test "project actions need the project policies" do
    assert_match "Non hai i permessi", tool.projects_create({ name: "New", year: 2026 })
    assert_match "Non hai i permessi", tool.projects_update({ project_id: @project.id, name: "Renamed" })
    assert_match "Non hai i permessi", tool.projects_duplicate({ source_project_id: @project.id, name: "Copy" })
    assert_match "Non hai i permessi", tool.projects_log_create({ project_id: @project.id, title: "Kickoff" })
    assert_empty tool.proposals
  end

  test "a confirmed project creation adds the user as member" do
    @user.update_policies([ "projects_create" ])
    contact = Contact.create!(name: "Imola")

    assert_no_difference "Project.count" do
      tool.projects_create({ name: "New website", year: 2026, code: "imo", contact_id: contact.id })
    end
    assert_equal "crea il progetto «New website» (2026), codice «IMO», contatto «Imola»", tool.proposals.last[:label]

    confirm_last_proposal
    project = Project.find_by!(name: "New website")
    assert_equal [ "IMO", contact.id ], [ project.code, project.contact_id ]
    assert project.projects_members.exists?(user: @user)
  end

  test "a project update changes only the given fields" do
    @user.update_policies([ "projects_edit" ])
    @project.update!(description: "Keep me")

    assert_match "Nessuna modifica", tool.projects_update({ project_id: @project.id })
    tool.projects_update({ project_id: @project.id, name: "Renamed" })
    confirm_last_proposal

    @project.reload
    assert_equal [ "Renamed", "Keep me" ], [ @project.name, @project.description ]
  end

  test "member-restricted user cannot update or copy projects of others" do
    @user.update_policies([ "projects_edit", "projects_create", "only_data_projects_as_member" ])

    assert_equal "Progetto non trovato", tool.projects_update({ project_id: @project.id, name: "Renamed" })
    assert_equal "Progetto da copiare non trovato", tool.projects_duplicate({ source_project_id: @project.id, name: "Copy" })
  end

  test "a duplicate gets new empty boards, never the source ones" do
    @user.update_policies([ "projects_create", "projects_manage_members", "projects_manage_procedures" ])
    contact = Contact.create!(name: "Imola")
    folder = Folder.create!(name: "Clienti")
    @project.update!(contact: contact)
    folder.folders_items.create!(resource: @project)
    @project.projects_members.create!(user: users(:two), role: "Developer")
    board = @project.procedures.create!(name: "Sviluppo", resources_type: "tasks")
    status = board.procedures_statuses.create!(title: "Da fare")
    task = Task.create!(title: "Old task", project: @project)
    task.procedures_items.create!(procedure: board, procedures_status: status)

    tool.projects_duplicate({ source_project_id: @project.id, name: "Copy", year: 2027 })
    assert_match "copiando «Project», contatto Imola, cartella Clienti, 1 membro e 1 board vuota", tool.proposals.last[:label]
    confirm_last_proposal

    copy = Project.find_by!(name: "Copy")
    assert_equal [ 2027, contact.id, folder.id ], [ copy.year, copy.contact_id, copy.folder.id ]
    assert_equal [ users(:two).id, @user.id ].sort, copy.projects_members.pluck(:user_id).sort
    new_board = copy.procedures.sole
    assert_not_equal board.id, new_board.id
    assert_equal [ "Sviluppo", [ "Da fare" ] ], [ new_board.name, new_board.procedures_statuses.pluck(:title) ]
    assert_empty new_board.procedures_items
    assert_equal [ board.id ], @project.procedures.pluck(:id)
  end

  test "a confirmed project note is written as the confirming user" do
    @user.update_policies([ "projects_manage_logs" ])
    assert_match "Data non valida", tool.projects_log_create({ project_id: @project.id, title: "Kickoff", date: "domani" })

    tool.projects_log_create({ project_id: @project.id, title: "Kickoff", content: "Riunione fatta\nProssimi passi", date: "2026-11-02" })
    assert_equal "aggiungi la nota «Kickoff» al progetto «Project», del 02/11/2026, «Riunione fatta\nProssimi passi»", tool.proposals.last[:label]
    confirm_last_proposal

    log = @project.projects_logs.sole
    assert_equal [ "Kickoff", @user.id, Date.new(2026, 11, 2) ], [ log.title, log.user_id, log.date ]
    assert_includes log.content.to_s, "Riunione fatta\n<br>Prossimi passi"
  end

  test "the budget management is set with the time budgets the form offers" do
    @user.update_policies([ "projects_edit" ])

    assert_match "Budget tempo non valido", tool.projects_update({ project_id: @project.id, budget_hours: 10 })
    assert_match "non può essere negativo", tool.projects_update({ project_id: @project.id, budget_money: -1 })

    tool.projects_update({ project_id: @project.id, budget_management: true, budget_money: 5000, budget_hours: 100 })
    assert_equal "modifica il progetto «Project»: gestione budget «attiva», budget economico «5000 €», budget tempo «12 giorni»", tool.proposals.last[:label]
    confirm_last_proposal

    @project.reload
    assert_equal [ true, 5000, 360_000 ], [ @project.budget_management, @project.budget_money, @project.budget_time ]
  end
end
