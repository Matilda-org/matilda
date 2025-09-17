# frozen_string_literal: true

require "test_helper"

class PostsControllerTest < ActionController::TestCase
  tests PostsController

  def setup
    setup_controller_test
  end

  # Test GET index with valid policy
  test "should get index" do
    @user.users_policies.create!(policy: "posts_index")
    get :index
    assert_response :success
    assert_not_nil @controller.instance_variable_get(:@posts)
    assert_not_nil @controller.instance_variable_get(:@tags)
  end

  # Test GET index without valid policy
  test "should not get index without valid policy" do
    get :index
    assert_redirected_to root_path
  end

  # Test GET actions create
  test "should get actions create" do
    get :actions, params: { type: "create" }
    assert_response :success
    assert_match(/Nuovo articolo/, @response.body)
  end

  # Test GET actions edit con id valido
  test "should get actions edit with valid id" do
    post = posts(:one)
    get :actions, params: { type: "edit", id: post.id }
    assert_response :success
    assert_match(/Modifica articolo/, @response.body)
  end

  # Test GET actions edit con id non valido
  test "should get actions edit with invalid id" do
    assert_raises ActiveRecord::RecordNotFound do
      get :actions, params: { type: "edit", id: 9999 }
    end
  end

  # Test GET actions destroy con id valido
  test "should get actions destroy with valid id" do
    post = posts(:one)
    get :actions, params: { type: "destroy", id: post.id }
    assert_response :success
    assert_match(/Elimina articolo/, @response.body)
  end

  # Test GET actions destroy con id non valido
  test "should get actions destroy with invalid id" do
    assert_raises ActiveRecord::RecordNotFound do
      get :actions, params: { type: "destroy", id: 9999 }
    end
  end

  # Test GET actions con tipo non valido
  test "should get actions with invalid type" do
    get :actions, params: { type: "invalid_type" }
    assert_response :success
    assert_match(/Si è verificato un errore/, @response.body)
  end

  # Test POST create_action con policy valida e parametri validi
  test "should post create_action with valid params and valid policy" do
    @user.users_policies.create!(policy: "posts_create")
    process :create_action, method: :post, params: { content: "Nuovo post", tags: "test", source_url: "http://example.com" }
    assert_response :success
    assert_match(/Articolo creato/, @response.body)
    assert Post.exists?(content: "Nuovo post")
  end

  # Test POST create_action senza policy valida
  test "should not post create_action without valid policy" do
    process :create_action, method: :post, params: { content: "Nuovo post", tags: "test", source_url: "http://example.com" }
    assert_redirected_to root_path
  end

  # Test POST edit_action con policy valida e parametri validi
  test "should post edit_action with valid params and valid policy" do
    @user.users_policies.create!(policy: "posts_edit")
    post_record = posts(:one)
    process :edit_action, method: :post, params: { id: post_record.id, content: "Post aggiornato" }
    assert_response :success
    assert_match(/Articolo aggiornato/, @response.body)
    post_record.reload
    assert_equal "Post aggiornato", post_record.content
  end

  # Test POST edit_action con policy valida e id non valido
  test "should not post edit_action with invalid id even with valid policy" do
    @user.users_policies.create!(policy: "posts_edit")
    process :edit_action, method: :post, params: { id: 9999, content: "Post aggiornato" }
    assert_redirected_to posts_path
  end

  # Test POST edit_action senza policy valida
  test "should not post edit_action without valid policy" do
    post_record = posts(:one)
    process :edit_action, method: :post, params: { id: post_record.id, content: "Post aggiornato" }
    assert_redirected_to root_path
  end

  # Test POST destroy_action con policy valida e parametri validi
  test "should post destroy_action with valid params and valid policy" do
    @user.users_policies.create!(policy: "posts_destroy")
    post_record = posts(:one)
    process :destroy_action, method: :post, params: { id: post_record.id }
    assert_response :success
    assert_match(/Articolo eliminato/, @response.body)
    assert_not Post.exists?(post_record.id)
  end

  # Test POST destroy_action con policy valida e id non valido
  test "should not post destroy_action with invalid id even with valid policy" do
    @user.users_policies.create!(policy: "posts_destroy")
    process :destroy_action, method: :post, params: { id: 9999 }
    assert_redirected_to posts_path
  end

  # Test POST destroy_action senza policy valida
  test "should not post destroy_action without valid policy" do
    post_record = posts(:one)
    process :destroy_action, method: :post, params: { id: post_record.id }
    assert_redirected_to root_path
    assert Post.exists?(post_record.id)
  end
end
