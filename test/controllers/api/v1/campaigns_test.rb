# frozen_string_literal: true

require "test_helper"

class Api::V1::CampaignsTest < ApiIntegrationTest
  test "index requires api key and campaigns_index policy" do
    assert_requires_api_key :get, "/api/v1/campaigns"
    assert_requires_policy :get, "/api/v1/campaigns", "crm"
  end

  test "show includes communications with their contact" do
    campaign = campaigns(:one)
    campaign.communications.create!(contact: contacts(:one))
    assert_requires_policy :get, "/api/v1/campaigns/#{campaign.id}", "crm"

    body = json_response
    assert_equal campaign.id, body["id"]
    assert_equal contacts(:one).id, body["communications"].first["contact"]["id"]
  end

  test "create_communication enqueues a contact as to_send" do
    campaign = campaigns(:one)
    assert_requires_policy :post, "/api/v1/campaigns/#{campaign.id}/communications", "crm",
      params: { contact_id: contacts(:one).id },
      success_status: :created

    communication = campaign.communications.find_by(contact_id: contacts(:one).id)
    assert communication.to_send?
  end

  test "create_communication rejects duplicates" do
    campaign = campaigns(:one)
    campaign.communications.create!(contact: contacts(:one))
    give_policy "crm"

    post "/api/v1/campaigns/#{campaign.id}/communications", params: { contact_id: contacts(:one).id }, headers: api_headers, as: :json
    assert_response :unprocessable_content
    assert json_response["errors"].any?
  end
end
