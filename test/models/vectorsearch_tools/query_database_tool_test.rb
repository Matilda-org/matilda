require "test_helper"

class VectorsearchTools::QueryDatabaseToolTest < ActiveSupport::TestCase
  setup do
    Rails.cache.clear
    @member_project = Project.create!(code: "MEM", name: "Member Project", year: 2026)
    @other_project = Project.create!(code: "OTH", name: "Other Project", year: 2026)
  end

  # user two, member of @member_project only, restricted to member projects
  def restricted_user
    user = users(:two)
    @member_project.projects_members.create!(user_id: user.id, role: "member")
    user.update_policies([ "only_data_projects_as_member" ])
    user
  end

  test "unrestricted user sees every project" do
    result = VectorsearchTools::QueryDatabaseTool.new(users(:one)).prjs({})

    assert_includes result, "Member Project"
    assert_includes result, "Other Project"
  end

  test "member-restricted user only sees their own projects" do
    result = VectorsearchTools::QueryDatabaseTool.new(restricted_user).prjs({})

    assert_includes result, "Member Project"
    assert_not_includes result, "Other Project"
  end

  test "member-restricted user cannot read tasks of other projects" do
    Task.create!(title: "Mine", project: @member_project)
    Task.create!(title: "Hidden", project: @other_project)

    result = VectorsearchTools::QueryDatabaseTool.new(restricted_user).tasks({})

    assert_includes result, "Mine"
    assert_not_includes result, "Hidden"
  end

  test "member-restricted user cannot read notes of another project" do
    log = @other_project.projects_logs.create!(title: "Secret", date: Date.today, content: "top secret", user: users(:one))

    tool = VectorsearchTools::QueryDatabaseTool.new(restricted_user)

    assert_equal "Nota non trovata", tool.prjs_log_content({ projects_log_id: log.id })
  end

  test "credentials tool is blocked without the credentials policy" do
    result = VectorsearchTools::QueryDatabaseTool.new(restricted_user).credentials({})

    assert_match "Non hai i permessi", result
  end

  test "credentials tool is allowed with the credentials policy" do
    user = users(:one)
    user.update_policies([ "credentials_index" ])
    Credential.create!(name: "GitHub")

    result = VectorsearchTools::QueryDatabaseTool.new(user).credentials({})

    assert_includes result, "GitHub"
  end

  test "crm tools are blocked without the crm policy" do
    tool = VectorsearchTools::QueryDatabaseTool.new(users(:two))

    assert_match "Non hai i permessi", tool.crm_contacts({})
    assert_match "Non hai i permessi", tool.crm_campaigns({})
    assert_match "Non hai i permessi", tool.crm_communications({})
  end

  test "crm tools list contacts, campaigns and their communications" do
    user = users(:one)
    user.update_policies([ "crm" ])
    Communication.create!(contact: contacts(:one), campaign: campaigns(:one))
    tool = VectorsearchTools::QueryDatabaseTool.new(user)

    assert_includes tool.crm_contacts({}), "Campaign One (Da inviare)"
    assert_includes tool.crm_campaigns({}), "1 da inviare"
    assert_includes tool.crm_communications({ status: "to_send" }), "Contact One"
  end

  test "crm communications filter keeps only the silent ones when asked" do
    user = users(:one)
    user.update_policies([ "crm" ])
    silent_contact = Contact.create!(name: "Silent")
    Communication.create!(contact: silent_contact, campaign: campaigns(:one), status: :sent, sent_date: 30.days.ago.to_date)
    Communication.create!(contact: contacts(:one), campaign: campaigns(:one), status: :sent, sent_date: Date.today)

    result = VectorsearchTools::QueryDatabaseTool.new(user).crm_communications({ needs_attention: true })

    assert_includes result, "Silent"
    assert_not_includes result, "Contact One"
  end

  test "tasks filters overdue, deadline range and unresolved" do
    tool = VectorsearchTools::QueryDatabaseTool.new(users(:one))
    Task.create!(title: "Late", deadline: 3.days.ago.to_date)
    Task.create!(title: "Next week", deadline: 8.days.from_now.to_date)
    Task.create!(title: "Waiting", user: users(:one)).tasks_comments.create!(content: "ping", user: users(:two))

    assert_includes tool.tasks({ overdue: true }), "Late"
    assert_not_includes tool.tasks({ overdue: true }), "Next week"

    in_range = tool.tasks({ deadline_from: 7.days.from_now.to_date.iso8601, deadline_to: 9.days.from_now.to_date.iso8601 })
    assert_includes in_range, "Next week"
    assert_not_includes in_range, "Late"

    unresolved = tool.tasks({ unresolved: true })
    assert_includes unresolved, "Waiting"
    assert_includes unresolved, "attende una risposta"
    assert_not_includes unresolved, "Late"
  end

  test "tasks show the checklist" do
    Task.create!(title: "With checks", tasks_checks_texts: [ "Write tests" ])

    assert_includes VectorsearchTools::QueryDatabaseTool.new(users(:one)).tasks({ search: "With checks" }), "Write tests (da fare)"
  end

  test "lists are capped and the model is told to narrow the filters" do
    (VectorsearchTools::QueryDatabaseTool::RESULTS_LIMIT + 1).times { |i| Task.create!(title: "Bulk #{i}") }

    result = VectorsearchTools::QueryDatabaseTool.new(users(:one)).tasks({ search: "Bulk" })

    assert_equal VectorsearchTools::QueryDatabaseTool::RESULTS_LIMIT, result.scan("Il task Bulk").size
    assert_includes result, "restringi i filtri"
  end

  test "member-restricted user cannot read comments of tasks of other projects" do
    hidden = Task.create!(title: "Hidden", project: @other_project)
    hidden.tasks_comments.create!(content: "secret comment", user: users(:one))
    mine = Task.create!(title: "Mine", project: @member_project)
    mine.tasks_comments.create!(content: "visible comment", user: users(:one))
    tool = VectorsearchTools::QueryDatabaseTool.new(restricted_user)

    assert_equal "Task non trovato", tool.task_comments({ task_id: hidden.id })
    assert_includes tool.task_comments({ task_id: mine.id }), "Rossi Mario ha scritto: visible comment"
  end

  test "time tracks sum the time per user and per task in the date range" do
    task = Task.create!(title: "Tracked", project: @member_project)
    task.tasks_tracks.create!(user: users(:one), start_at: 2.days.ago, end_at: 2.days.ago + 1.hour, time_spent: 3600)
    task.tasks_tracks.create!(user: users(:one), start_at: 20.days.ago, end_at: 20.days.ago + 1.hour, time_spent: 3600)

    result = VectorsearchTools::QueryDatabaseTool.new(users(:one)).time_tracks({ date_from: 7.days.ago.to_date.iso8601 })

    assert_includes result, "Tempo totale tracciato: 01h 00m"
    assert_includes result, "Rossi Mario 01h 00m"
    assert_includes result, "Tracked (ID: #{task.id}) 01h 00m"
  end

  test "member-restricted user does not see time tracked on other projects" do
    Task.create!(title: "Hidden", project: @other_project).tasks_tracks.create!(user: users(:one), start_at: 1.day.ago, time_spent: 3600)

    assert_includes VectorsearchTools::QueryDatabaseTool.new(restricted_user).time_tracks({}), "Tempo totale tracciato: 00h 00m"
  end

  test "users resolves a name to its ID" do
    result = VectorsearchTools::QueryDatabaseTool.new(users(:one)).users({ search: "luisa bia" })

    assert_includes result, "Bianchi Luisa (ID: #{users(:two).id})"
    assert_not_includes result, "Mario"
  end

  test "crm communication logs need the crm policy and return the notes" do
    communication = Communication.create!(contact: contacts(:one), campaign: campaigns(:one))
    communication.communications_logs.create!(content: "Called, asked for a quote", user: users(:one))

    assert_match "Non hai i permessi", VectorsearchTools::QueryDatabaseTool.new(users(:two)).crm_communication_logs({ communication_id: communication.id })

    user = users(:one)
    user.update_policies([ "crm" ])
    assert_includes VectorsearchTools::QueryDatabaseTool.new(user).crm_communication_logs({ communication_id: communication.id }), "Called, asked for a quote"
  end
end
