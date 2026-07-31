# frozen_string_literal: true

require "test_helper"

class Api::V1::UsersTest < ApiIntegrationTest
  test "me requires api key" do
    assert_requires_api_key :get, "/api/v1/me"
  end

  test "me returns the authenticated user without secrets" do
    get "/api/v1/me", headers: api_headers
    assert_response :success

    body = json_response
    assert_equal @user.id, body["id"]
    assert_equal @user.email, body["email"]
    assert_kind_of Array, body["policies"]
    assert_not_includes body.keys, "api_key"
    assert_not_includes body.keys, "password_digest"
  end

  test "index requires users_index policy" do
    assert_requires_policy :get, "/api/v1/users", "users_index"
  end

  test "index returns paginated users" do
    give_policy "users_index"
    get "/api/v1/users", headers: api_headers

    body = json_response
    assert_equal User.count, body["meta"]["total_count"]
    assert_equal User.count, body["data"].size
    body["data"].each do |user|
      assert_not_includes user.keys, "api_key"
      assert_not_includes user.keys, "password_digest"
    end
  end

  test "show requires users_show policy and returns the user" do
    assert_requires_policy :get, "/api/v1/users/#{users(:two).id}", "users_show"

    body = json_response
    assert_equal users(:two).id, body["id"]
    assert_not_includes body.keys, "api_key"
  end

  test "show returns 404 for unknown user" do
    give_policy "users_show"
    get "/api/v1/users/9999", headers: api_headers
    assert_response :not_found
  end
end
