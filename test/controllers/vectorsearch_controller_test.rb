# frozen_string_literal: true

require "test_helper"

class VectorsearchControllerTest < ActionController::TestCase
  tests VectorsearchController

  def setup
    setup_controller_test
  end

  test "chat" do
    matilda_controller_endpoint(:get, :chat)
  end
end
