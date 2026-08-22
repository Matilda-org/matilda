# frozen_string_literal: true

require "test_helper"

class CampaignsControllerTest < ActionController::TestCase
  tests CampaignsController

  def setup
    setup_controller_test
  end

  test "actions" do
    campaign = campaigns(:one)
    communication = campaign.communications.create!(contact: contacts(:one))

    matilda_controller_action("create", "Nuova campagna")
    matilda_controller_action("edit", "Modifica campagna", campaign.id)
    matilda_controller_action("archive", "Archivia campagna", campaign.id)
    matilda_controller_action("unarchive", "Ri-attiva campagna", campaign.id)
    matilda_controller_action("destroy", "Elimina campagna", campaign.id)
    matilda_controller_action("add-communication", "Aggiungi comunicazione", campaign.id)
    matilda_controller_action("send-communication", "Conferma invio", campaign.id, { communication_id: communication.id })
    matilda_controller_action("show-communication", "Note comunicazione", campaign.id, { communication_id: communication.id })
    matilda_controller_action("remove-communication", "Elimina comunicazione", campaign.id, { communication_id: communication.id })

    communication.mark_sent(Date.today)
    matilda_controller_action("close-communication", "Registra esito", campaign.id, { communication_id: communication.id })

    matilda_controller_action_invalid
  end

  test "index" do
    matilda_controller_endpoint(:get, :index,
      policy: "crm"
    )
  end

  test "show" do
    campaign = campaigns(:one)
    campaign.communications.create!(contact: contacts(:one))
    matilda_controller_endpoint(:get, :show,
      params: { id: campaign.id },
      policy: "crm"
    )
  end

  test "create_action" do
    matilda_controller_endpoint(:post, :create_action,
      params: { name: "Test Campaign", description: "Demo" },
      policy: "crm",
      title: "Nuova campagna",
      feedback: "Campagna creata"
    )

    assert_not_nil Campaign.find_by(name: "Test Campaign")
  end

  test "edit_action" do
    campaign = campaigns(:one)
    matilda_controller_endpoint(:post, :edit_action,
      params: { id: campaign.id, name: "Updated Campaign" },
      policy: "crm",
      title: "Modifica campagna",
      feedback: "Campagna aggiornata"
    )

    assert_equal "Updated Campaign", campaign.reload.name
  end

  test "destroy_action" do
    campaign = campaigns(:one)
    matilda_controller_endpoint(:post, :destroy_action,
      params: { id: campaign.id },
      policy: "crm",
      title: "Elimina campagna",
      feedback: "Campagna eliminata"
    )

    assert_not Campaign.exists?(campaign.id)
  end

  test "archive_action and unarchive_action" do
    campaign = campaigns(:one)

    matilda_controller_endpoint(:post, :archive_action,
      params: { id: campaign.id },
      policy: "crm",
      title: "Archivia campagna",
      feedback: "Campagna archiviata"
    )
    assert campaign.reload.archived

    matilda_controller_endpoint(:post, :unarchive_action,
      params: { id: campaign.id },
      policy: "crm",
      title: "Ri-attiva campagna",
      feedback: "Campagna ri-attivata"
    )
    assert_not campaign.reload.archived
  end

  test "add_communication_action" do
    campaign = campaigns(:one)
    matilda_controller_endpoint(:post, :add_communication_action,
      params: { id: campaign.id, contact_id: contacts(:one).id },
      policy: "crm",
      title: "Aggiungi comunicazione",
      feedback: "Comunicazione creata"
    )

    communication = campaign.communications.find_by(contact_id: contacts(:one).id)
    assert communication.to_send?
  end

  test "send_communication_action stores the confirmed date" do
    campaign = campaigns(:one)
    communication = campaign.communications.create!(contact: contacts(:one))

    matilda_controller_endpoint(:post, :send_communication_action,
      params: { id: campaign.id, communication_id: communication.id, sent_date: Date.today - 1.day },
      policy: "crm",
      title: "Conferma invio",
      feedback: "Comunicazione inviata"
    )

    communication.reload
    assert communication.sent?
    assert_equal Date.today - 1.day, communication.sent_date
  end

  test "close_communication_action stores outcome and date" do
    campaign = campaigns(:one)
    communication = campaign.communications.create!(contact: contacts(:one))
    communication.mark_sent(Date.today - 5.days)

    matilda_controller_endpoint(:post, :close_communication_action,
      params: { id: campaign.id, communication_id: communication.id, final_status: "won", closed_date: Date.today },
      policy: "crm",
      title: "Registra esito",
      feedback: "Esito registrato"
    )

    communication.reload
    assert communication.won?
    assert_equal Date.today, communication.closed_date
  end

  test "follow_up_communication_action increments the counter" do
    campaign = campaigns(:one)
    communication = campaign.communications.create!(contact: contacts(:one))
    communication.mark_sent(Date.today - 5.days)

    matilda_controller_endpoint(:post, :follow_up_communication_action,
      params: { id: campaign.id, communication_id: communication.id },
      policy: "crm",
      title: "Registra follow-up",
      feedback: "Follow-up registrato"
    )

    assert_equal 1, communication.reload.follow_ups_count
  end

  test "remove_communication_action" do
    campaign = campaigns(:one)
    communication = campaign.communications.create!(contact: contacts(:one))

    matilda_controller_endpoint(:post, :remove_communication_action,
      params: { id: campaign.id, communication_id: communication.id },
      policy: "crm",
      title: "Elimina comunicazione",
      feedback: "Comunicazione eliminata"
    )

    assert_not Communication.exists?(communication.id)
  end

  test "communication logs add and remove" do
    campaign = campaigns(:one)
    communication = campaign.communications.create!(contact: contacts(:one))

    matilda_controller_endpoint(:post, :add_communication_log_action,
      params: { id: campaign.id, communication_id: communication.id, content: "Nota di test" },
      policy: "crm",
      title: "Aggiungi nota",
      feedback: "Nota aggiunta"
    )

    log = communication.communications_logs.find_by(content: "Nota di test")
    assert_not_nil log
    assert_equal @user.id, log.user_id

    matilda_controller_endpoint(:post, :remove_communication_log_action,
      params: { id: campaign.id, communication_id: communication.id, log_id: log.id },
      policy: "crm",
      title: "Rimuovi nota",
      feedback: "Nota rimossa"
    )

    assert_not communication.communications_logs.exists?(log.id)
  end
end
