require "test_helper"

class ApisControllerTest < ActionController::TestCase
  tests ApisController

  def setup
    Setting.set("functionalities_api_key", "test_api_key")
  end

  test "should return unauthorized without api key setting" do
    Setting.set("functionalities_api_key", nil)
    procedure = procedures(:one)
    get :procedure, params: { id: procedure.id }
    assert_response :unauthorized
  end

  test "should return unauthorized without api key parameter" do
    procedure = procedures(:one)
    get :procedure, params: { id: procedure.id }
    assert_response :unauthorized
  end

  test "should return unauthorized with an invalid api key" do
    procedure = procedures(:one)
    get :procedure, params: { id: procedure.id, api_key: "invalid_api_key" }
    assert_response :unauthorized
  end

  test "should get procedure" do
    procedure = procedures(:one)
    get :procedure, params: { id: procedure.id, api_key: "test_api_key" }
    assert_response :success
  end

  test "should get task" do
    task = tasks(:one)
    get :task, params: { id: task.id, api_key: "test_api_key" }
    assert_response :success
  end

  test "should update task title" do
    task = tasks(:one)
    patch :task_update, params: { id: task.id, api_key: "test_api_key", task: { title: "Updated Task Title" } }
    assert_response :success
    task.reload
    assert_equal "Updated Task Title", task.title
  end

  test "should return unprocessable_content when updating task with too long title" do
    task = tasks(:one)
    long_title = "A" * 201
    patch :task_update, params: { id: task.id, api_key: "test_api_key", task: { title: long_title } }
    assert_response :unprocessable_content
    json_response = JSON.parse(@response.body)
    assert_includes json_response["errors"], "Title è troppo lungo (il massimo è 200 caratteri)"
  end

  test "should return json not_found for a missing task" do
    get :task, params: { id: 0, api_key: "test_api_key" }
    assert_response :not_found
    json_response = JSON.parse(@response.body)
    assert_equal "Risorsa non trovata", json_response["error"]
  end

  test "should return json bad_request when task param is missing on update" do
    task = tasks(:one)
    patch :task_update, params: { id: task.id, api_key: "test_api_key" }
    assert_response :bad_request
    json_response = JSON.parse(@response.body)
    assert_includes json_response["error"], "Parametro mancante"
  end
end
