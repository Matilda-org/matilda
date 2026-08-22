# frozen_string_literal: true

require "test_helper"

class Api::V1::ContactsTest < ApiIntegrationTest
  test "index requires api key and contacts_index policy" do
    assert_requires_api_key :get, "/api/v1/contacts"
    assert_requires_policy :get, "/api/v1/contacts", "crm"
  end

  test "index searches by name" do
    target = Contact.create!(name: "Findme Srl")
    give_policy "crm"

    get "/api/v1/contacts", params: { search: "findme" }, headers: api_headers
    assert_equal [ target.id ], json_response["data"].map { |c| c["id"] }
  end

  test "show includes communications and projects" do
    contact = contacts(:one)
    campaigns(:one).communications.create!(contact: contact)
    assert_requires_policy :get, "/api/v1/contacts/#{contact.id}", "crm"

    body = json_response
    assert_equal contact.id, body["id"]
    assert body.key?("communications")
    assert body.key?("projects")
  end

  test "create requires contacts_create policy and returns validation errors" do
    assert_requires_policy :post, "/api/v1/contacts", "crm",
      params: { name: "API contact", email: "api@contact.com" },
      success_status: :created

    assert_not_nil Contact.find_by(name: "API contact")

    post "/api/v1/contacts", params: { name: "" }, headers: api_headers, as: :json
    assert_response :unprocessable_content
    assert json_response["errors"].any?
  end
end
