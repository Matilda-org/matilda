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

  test "send moves the communication to sent and stores the date" do
    assert_requires_policy :post, "/api/v1/communications/#{communication.id}/send", "crm",
      params: { sent_date: Date.today - 2.days }

    communication.reload
    assert communication.sent?
    assert_equal Date.today - 2.days, communication.sent_date
    assert_equal "sent", json_response["status"]
  end

  test "send defaults to today and refuses to run twice" do
    give_policy "crm"

    post "/api/v1/communications/#{communication.id}/send", headers: api_headers, as: :json
    assert_response :success
    assert_equal Date.today, communication.reload.sent_date

    post "/api/v1/communications/#{communication.id}/send", headers: api_headers, as: :json
    assert_response :unprocessable_content
    assert json_response["errors"].any?
  end

  test "close stores the outcome and its date" do
    communication.mark_sent(Date.today - 5.days)
    assert_requires_policy :post, "/api/v1/communications/#{communication.id}/close", "crm",
      params: { status: "won", closed_date: Date.today - 1.day }

    communication.reload
    assert communication.won?
    assert_equal Date.today - 1.day, communication.closed_date
  end

  test "close validates the outcome and never goes backwards" do
    give_policy "crm"

    # not sent yet
    post "/api/v1/communications/#{communication.id}/close", params: { status: "won" }, headers: api_headers, as: :json
    assert_response :unprocessable_content

    communication.mark_sent(Date.today)
    post "/api/v1/communications/#{communication.id}/close", params: { status: "bogus" }, headers: api_headers, as: :json
    assert_response :unprocessable_content
    assert json_response["errors"].any?

    post "/api/v1/communications/#{communication.id}/close", params: { status: "lost" }, headers: api_headers, as: :json
    assert_response :success

    # already closed: no second outcome
    post "/api/v1/communications/#{communication.id}/close", params: { status: "won" }, headers: api_headers, as: :json
    assert_response :unprocessable_content
    assert communication.reload.lost?
  end

  test "follow_up creates a dated record only while sent" do
    give_policy "crm"

    post "/api/v1/communications/#{communication.id}/follow_up", headers: api_headers, as: :json
    assert_response :unprocessable_content

    communication.mark_sent(Date.today - 5.days)
    post "/api/v1/communications/#{communication.id}/follow_up", params: { date: Date.today - 1.day }, headers: api_headers, as: :json
    assert_response :created
    assert_equal (Date.today - 1.day).to_s, json_response["date"]
    assert_equal @user.id, json_response["user_id"]
    assert_equal 1, communication.reload.follow_ups_count

    communication.mark_closed("won", Date.today)
    post "/api/v1/communications/#{communication.id}/follow_up", headers: api_headers, as: :json
    assert_response :unprocessable_content
  end

  test "destroy_follow_up undoes it and keeps the counter in sync" do
    communication.mark_sent(Date.today - 5.days)
    follow_up = communication.register_follow_up
    give_policy "crm"

    delete "/api/v1/communications/#{communication.id}/follow_ups/#{follow_up.id}", headers: api_headers
    assert_response :no_content
    assert_equal 0, communication.reload.follow_ups_count

    delete "/api/v1/communications/#{communication.id}/follow_ups/#{follow_up.id}", headers: api_headers
    assert_response :not_found
  end

  test "show lists the follow-ups of the communication" do
    communication.mark_sent(Date.today - 5.days)
    communication.register_follow_up(Date.today - 2.days)
    give_policy "crm"

    get "/api/v1/communications/#{communication.id}", headers: api_headers
    assert_equal [ (Date.today - 2.days).to_s ], json_response["communications_follow_ups"].map { |f| f["date"] }
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
