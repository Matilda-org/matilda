# frozen_string_literal: true

require "test_helper"

class SettingsControllerTest < ActionController::TestCase
  tests SettingsController

  def setup
    setup_controller_test
  end

  test "index" do
    matilda_controller_endpoint(:get, :index,
      policy: "settings"
    )
  end

  test "edit_infos_action" do
    matilda_controller_endpoint(:post, :edit_infos_action,
      params: {
        infos_company_name: "New Company",
        infos_company_website: "https://newcompany.com",
        infos_company_vat: "NEWVAT123",
        infos_company_email: "info@newcompany.com",
        infos_company_pec: "pec@newcompany.com"
      },
      policy: "settings",
      redirect: settings_path
    )

    assert_equal "New Company", Setting.get("infos_company_name")
    assert_equal "https://newcompany.com", Setting.get("infos_company_website")
    assert_equal "NEWVAT123", Setting.get("infos_company_vat")
    assert_equal "info@newcompany.com", Setting.get("infos_company_email")
    assert_equal "pec@newcompany.com", Setting.get("infos_company_pec")
  end

  test "edit_functionalities_action" do
    matilda_controller_endpoint(:post, :edit_functionalities_action,
      params: {
        functionalities_api_key: "newapikey123",
        functionalities_task_acceptance: 1
      },
      policy: "settings",
      redirect: settings_path
    )

    assert_equal "newapikey123", Setting.get("functionalities_api_key")
    assert_equal true, Setting.get("functionalities_task_acceptance")
  end

  test "edit_vectorsearch_action" do
    matilda_controller_endpoint(:post, :edit_vectorsearch_action,
      params: {
        vectorsearch_openai_key: "newopenaikey123"
      },
      policy: "settings",
      redirect: settings_path
    )

    assert_equal "newopenaikey123", Setting.get("vectorsearch_openai_key")
  end

  test "edit_slack_action" do
    matilda_controller_endpoint(:post, :edit_slack_action,
      params: {
        slack_bot_user_oauth_token: "newslacktoken123",
        slack_verification_token: "newverificationtoken123"
      },
      policy: "settings",
      redirect: settings_path
    )

    assert_equal "newslacktoken123", Setting.get("slack_bot_user_oauth_token")
    assert_equal "newverificationtoken123", Setting.get("slack_verification_token")
  end

  test "reset_action" do
    Setting.set("infos_company_name", "To Be Reset")
    matilda_controller_endpoint(:post, :reset_action,
      params: { key: "infos_company" },
      policy: "settings",
      redirect: settings_path
    )

    assert_nil Setting.get("infos_company_name")
  end
end
