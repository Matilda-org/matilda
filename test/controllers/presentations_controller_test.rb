# frozen_string_literal: true

require "test_helper"

class PresentationsControllerTest < ActionController::TestCase
  tests PresentationsController

  def setup
    setup_controller_test
  end

  test "actions" do
    presentation = presentations(:one)
    matilda_controller_action("create", "Nuova presentazione")
    matilda_controller_action("import", "Importa pagine", presentation.id)
    matilda_controller_action("edit", "Modifica presentazione", presentation.id)
    matilda_controller_action("destroy", "Elimina presentazione", presentation.id)

    matilda_controller_action_invalid
  end

  test "index" do
    matilda_controller_endpoint(:get, :index,
      policy: "presentations_index"
    )
  end
end
