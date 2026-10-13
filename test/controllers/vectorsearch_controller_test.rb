# frozen_string_literal: true

require "test_helper"

class VectorsearchControllerTest < ActionController::TestCase
  tests VectorsearchController

  def setup
    setup_controller_test
  end

  # Replaces the OpenAI call with a canned answer and records the request,
  # so the endpoints are tested without network or API key.
  def with_ai_answer(answer)
    requests = []
    original = Vectorsearch.method(:ask)
    Vectorsearch.define_singleton_method(:ask) do |**kwargs|
      requests << kwargs
      answer.is_a?(Exception) ? raise(answer) : answer
    end
    yield requests
  ensure
    Vectorsearch.define_singleton_method(:ask, original)
  end

  test "chat" do
    matilda_controller_endpoint(:get, :chat)
  end

  test "communication_draft requires the crm policy" do
    communication = Communication.create!(contact: contacts(:one), campaign: campaigns(:one))

    post :communication_draft, params: { communication_id: communication.id }

    assert_response :forbidden
  end

  test "communication_draft drafts the first message from the communication context" do
    @user.users_policies.create!(policy: "crm")
    communication = Communication.create!(contact: contacts(:one), campaign: campaigns(:one))

    with_ai_answer("Gentile Contact One, ...") do |requests|
      post :communication_draft, params: { communication_id: communication.id }

      assert_response :success
      assert_equal "Gentile Contact One, ...", response.parsed_body["draft"]
      assert_includes requests.first[:instructions], "first message"
      assert_includes requests.first[:content], "Contact: Contact One"
      assert_includes requests.first[:content], "Campaign: Campaign One"
    end
  end

  test "communication_draft refuses closed communications" do
    @user.users_policies.create!(policy: "crm")
    communication = Communication.create!(contact: contacts(:one), campaign: campaigns(:one), status: :sent, sent_date: Date.today)
    communication.mark_closed("won", Date.today)

    post :communication_draft, params: { communication_id: communication.id }

    assert_response :unprocessable_entity
  end

  test "text_to_task returns only the task fields" do
    answer = { "title" => "Call Mario", "deadline" => "2026-10-20", "time_estimate_minutes" => 30, "user_id" => @user.id, "checklist" => [ "Prepare" ], "extra" => "x" }

    with_ai_answer(answer) do |requests|
      post :text_to_task, params: { text: "<div>Call Mario next week</div>" }

      assert_response :success
      assert_equal answer.except("extra"), response.parsed_body
      assert_equal "Call Mario next week", requests.first[:content]
      assert requests.first[:json]
    end
  end

  test "text_to_task needs a text" do
    post :text_to_task, params: { text: "" }

    assert_response :unprocessable_entity
  end

  test "text_to_contact sends text and image to the model" do
    image = Rack::Test::UploadedFile.new(StringIO.new("fake-png"), "image/png", original_filename: "card.png")

    with_ai_answer({ "name" => "Acme", "email" => "info@acme.test" }) do |requests|
      post :text_to_contact, params: { text: "Acme srl", image: image }

      assert_response :success
      assert_equal "Acme", response.parsed_body["name"]
      parts = requests.first[:content]
      assert_equal "Acme srl", parts.first[:text]
      assert parts.last[:image_url][:url].start_with?("data:image/png;base64,")
    end
  end

  test "text_to_contact rejects files that are not images" do
    file = Rack::Test::UploadedFile.new(StringIO.new("%PDF"), "application/pdf", original_filename: "card.pdf")

    post :text_to_contact, params: { image: file }

    assert_response :unprocessable_entity
  end

  test "ai failures answer with a readable error" do
    with_ai_answer(StandardError.new("timeout")) do
      post :text_to_task, params: { text: "Call Mario" }

      assert_response :bad_gateway
      assert_match "riprova", response.parsed_body["error"]
    end
  end
end
