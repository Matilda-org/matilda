# frozen_string_literal: true

require "test_helper"

class PresentationsControllerTest < ActionController::TestCase
  tests PresentationsController

  def setup
    setup_controller_test
  end

  test "index" do
    matilda_controller_endpoint(:get, :index,
      policy: "presentations_index"
    )
  end
end
