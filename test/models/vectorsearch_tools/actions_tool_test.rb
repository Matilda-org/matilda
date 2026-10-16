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
end
