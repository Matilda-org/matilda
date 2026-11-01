# frozen_string_literal: true

require "test_helper"

class ApplicationControllerTest < ActionDispatch::IntegrationTest
  test "cacheclear rejects anonymous requests" do
    Rails.cache.write("sentinel", true)
    get cacheclear_path

    assert_redirected_to authentication_login_path(redirect: cacheclear_path)
    assert Rails.cache.read("sentinel")
  end
end
