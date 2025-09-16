# frozen_string_literal: true

require "test_helper"

class ProceduresControllerTest < ActionController::TestCase
  tests ProceduresController

  def setup
    @user = users(:one)
    cookies.encrypted[:user_id] = @user.id

    Rails.cache.clear
    ActionMailer::Base.deliveries.clear
  end

  # Tests for GET index with valid policy
  test "should get index with valid policy" do
    @user.users_policies.create!(policy: "procedures_index")
    get :index
    assert_response :success
    assert_not_nil @controller.instance_variable_get(:@procedures)
    assert_not_nil @controller.instance_variable_get(:@procedures_preferred)
  end

  # Tests for GET index without valid policy
  test "should get index without valid policy" do
    get :index
    assert_redirected_to root_path
  end

  # Tests for GET show
  test "should get show with valid policy" do
    @user.users_policies.create!(policy: "procedures_show")
    procedure = procedures(:one)
    get :show, params: { id: procedure.id }
    assert_response :success
    assert_not_nil @controller.instance_variable_get(:@procedure)
  end
end
