# frozen_string_literal: true

require "test_helper"

class CrmControllerTest < ActionController::TestCase
  tests CrmController

  def setup
    setup_controller_test
  end

  test "index" do
    campaign = campaigns(:one)
    campaign.communications.create!(contact: contacts(:one))
    sent = Campaign.create!(name: "Sent campaign").communications.create!(contact: contacts(:one))
    sent.mark_sent(Date.today - 3.days)

    matilda_controller_endpoint(:get, :index,
      policy: "crm"
    )
  end

  test "index stat tiles link to the communication lists" do
    @user.users_policies.create!(policy: "crm")
    get :index

    assert_response :success
    assert_includes @response.body, "href=\"#crm-to-send\""
    assert_includes @response.body, "id=\"crm-to-send\""
    assert_includes @response.body, "id=\"crm-waiting\""
  end
end
