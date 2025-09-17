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

  # Open SimpleCov coverage report after tests are run
  Minitest.after_run do
    begin
      # `open coverage/index.html`
    rescue
      puts "Unable to open coverage report. Please navigate to coverage/index.html in your browser."
    end
  end

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

  def assert_controller_actions(title = nil)
    assert_response :success
    assert @response.body.include?("id=\"action-controller\"")
    assert @response.body.include?("<h3 class=\"modal-title fs-5\">#{title}</h3>") if title
  end

  def assert_controller_actions_invalid
    assert_response :success
    assert @response.body.include?("id=\"action-controller\"")
    assert @response.body.include?("<h3 class=\"modal-title fs-5\">Errore</h3>")
  end
end
