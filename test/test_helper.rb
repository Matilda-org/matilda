ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"

# Setup SimpleCov for test coverage analysis
require "simplecov"
SimpleCov.start "rails"

class ActiveSupport::TestCase
  # Run tests in parallel with specified workers
  parallelize(workers: 1) # :number_of_processors

  # Setup all fixtures in test/fixtures/*.yml for all tests in alphabetical order.
  fixtures :all

  # # Open SimpleCov coverage report after tests are run
  # Minitest.after_run do
  #   begin
  #     `open coverage/index.html`
  #   rescue
  #     puts "Unable to open coverage report. Please navigate to coverage/index.html in your browser."
  #   end
  # end

  # Add more helper methods to be used by all tests here...

  def setup_controller_test
    @user = users(:one)
    cookies.encrypted[:user_id] = @user.id

    Rails.cache.clear
    ActionMailer::Base.deliveries.clear
  end

  def assert_controller_invalid_policy
    assert_redirected_to root_path
  end
end

# Shared helpers for API (/api/v1) integration tests.
class ApiIntegrationTest < ActionDispatch::IntegrationTest
  def setup
    @user = users(:one)
    Rails.cache.clear
  end

  # Headers authenticating the request with the user's personal API key.
  def api_headers(user = @user)
    { "X-API-Key" => user.api_key }
  end

  def give_policy(policy, user = @user)
    user.users_policies.create!(policy: policy)
    Rails.cache.clear
  end

  def json_response
    JSON.parse(@response.body)
  end

  # Every endpoint must reject requests without a valid API key.
  def assert_requires_api_key(method, path)
    send(method, path)
    assert_response :unauthorized

    send(method, path, headers: { "X-API-Key" => "invalid_key" })
    assert_response :unauthorized
  end

  # Every policy-gated endpoint must return 403 without the policy
  # and succeed once the user has it.
  def assert_requires_policy(method, path, policy, params: {}, success_status: :success)
    send(method, path, params: params, headers: api_headers, as: :json)
    assert_response :forbidden

    give_policy(policy)
    send(method, path, params: params, headers: api_headers, as: :json)
    assert_response success_status
  end
end

class ActionController::TestCase
  def matilda_controller_action(type, title = nil, id = nil, other_params = {})
    # test valid request
    get :actions, params: { type: type, id: id }.merge(other_params)
    assert_response :success
    assert @response.body.include?("id=\"action-controller\"")
    assert @response.body.include?("<h3 class=\"modal-title fs-5\">#{title}</h3>") if title

    # test invalid id
    if id
      assert_raises ActiveRecord::RecordNotFound do
        get :actions, params: { type: type, id: 9999 }.merge(other_params)
      end
    end
  end

  def matilda_controller_action_invalid
    get :actions, params: { type: "invalid_type" }
    assert_response :success
    assert @response.body.include?("id=\"action-controller\"")
    assert @response.body.include?("<h3 class=\"modal-title fs-5\">Errore</h3>")
  end

  def matilda_controller_endpoint(method, endpoint, params: {}, policy: nil, title: nil, feedback: nil, redirect: nil, debug: false)
    @user.users_policies.create!(policy: policy) if policy
    send(method, endpoint, params: params)

    if debug
      puts "*" * 100
      puts "DEBUG #{method.upcase} #{endpoint} with params: #{params} and policy: #{policy}"
      puts @response.body
      puts "*" * 100
    end

    if title
      assert_response :success
      assert @response.body.include?("id=\"action-controller\"")
      assert @response.body.include?("<h3 class=\"modal-title fs-5\">#{title}</h3>")
      if feedback
        assert @response.body.include?("<h3 class=\"fs-5 mb-1\">#{feedback}</h3>")
      end
    elsif redirect
      assert_redirected_to redirect
    else
      assert_response :success
    end

    # test invalid policy
    if policy
      @user.users_policies.destroy_all
      send(method, endpoint, params: params)
      assert_redirected_to root_path
    end
  end
end
