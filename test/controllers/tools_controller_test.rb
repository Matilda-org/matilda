# frozen_string_literal: true

require "test_helper"

class ToolsControllerTest < ActionController::TestCase
  tests ToolsController

  def setup
    setup_controller_test
  end

  test "index" do
    matilda_controller_endpoint(:get, :index,
      policy: "tools"
    )
  end

  test "projects_without_procedures" do
    matilda_controller_endpoint(:get, :projects_without_procedures,
      policy: "tools"
    )
  end

  test "projects_tasks_tracking" do
    matilda_controller_endpoint(:get, :projects_tasks_tracking,
      policy: "tools"
    )
  end
end
