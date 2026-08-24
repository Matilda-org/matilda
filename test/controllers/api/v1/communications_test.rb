# frozen_string_literal: true

require "test_helper"

class Api::V1::CommunicationsTest < ApiIntegrationTest
  def communication
    @communication ||= campaigns(:one).communications.create!(contact: contacts(:one))
  end

  test "show requires api key and crm policy and includes contact and campaign" do
    assert_requires_api_key :get, "/api/v1/communications/#{communication.id}"
    assert_requires_policy :get, "/api/v1/communications/#{communication.id}", "crm"

    body = json_response
    assert_equal contacts(:one).id, body["contact"]["id"]
    assert_equal campaigns(:one).id, body["campaign"]["id"]
  end

  test "logs returns the notes with their html content, most recent first" do
    old = communication.communications_logs.create!(content: "<div>Prima nota</div>")
    recent = communication.communications_logs.create!(content: "<div>Seconda <strong>nota</strong></div>")
    old.update_column(:created_at, 2.days.ago)

    assert_requires_policy :get, "/api/v1/communications/#{communication.id}/logs", "crm"

    data = json_response["data"]
    assert_equal [ recent.id, old.id ], data.map { |l| l["id"] }
    assert_includes data.first["content"], "<strong>nota</strong>"
  end

  test "create_log attributes the note to the api key user" do
    assert_requires_policy :post, "/api/v1/communications/#{communication.id}/logs", "crm",
      params: { content: "<div>Nota da tool esterno</div>" },
      success_status: :created

    log = communication.communications_logs.last
    assert_equal "Nota da tool esterno", log.content.to_plain_text
    assert_equal @user.id, log.user_id
    assert_includes json_response["content"], "Nota da tool esterno"
  end

  test "create_log validates the content" do
    give_policy "crm"

    [ { content: "  " }, { content: "<div> </div>" }, {} ].each do |params|
      post "/api/v1/communications/#{communication.id}/logs", params: params, headers: api_headers, as: :json
      assert_response :unprocessable_content
      assert json_response["errors"].any?
    end
  end

  test "destroy_log removes the note" do
    log = communication.communications_logs.create!(content: "<div>Da eliminare</div>")
    give_policy "crm"

    delete "/api/v1/communications/#{communication.id}/logs/#{log.id}", headers: api_headers
    assert_response :no_content
    assert_not Communications::Log.exists?(log.id)
  end

  test "destroy_log returns 404 for a note of another communication" do
    other = Campaign.create!(name: "Other campaign").communications.create!(contact: contacts(:one))
    log = other.communications_logs.create!(content: "<div>Altrui</div>")
    give_policy "crm"

    delete "/api/v1/communications/#{communication.id}/logs/#{log.id}", headers: api_headers
    assert_response :not_found
    assert Communications::Log.exists?(log.id)
  end
end
