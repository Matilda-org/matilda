ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"

# Setup SimpleCov for test coverage analysis
require "simplecov"
SimpleCov.start "rails"

class ActiveSupport::TestCase
  # Run tests in parallel with specified workers
  parallelize(workers: :number_of_processors)

  # Setup all fixtures in test/fixtures/*.yml for all tests in alphabetical order.
  fixtures :all

  # Open SimpleCov coverage report after tests are run
  Minitest.after_run do
    begin
      `open coverage/index.html`
    rescue
      puts "Unable to open coverage report. Please navigate to coverage/index.html in your browser."
    end
  end

  # Add more helper methods to be used by all tests here...
end
