# frozen_string_literal: true

# SettingsController.
class SettingsController < ApplicationController
  before_action :validate_session_user!
  before_action :validate_policy_settings
  before_action do
    @_navbar = 'settings'
  end

  caches_action :index, cache_path: -> { current_cache_action_path }, layout: false
  def index; end

  def edit_infos_action
    p = params.permit(:infos_company_name, :infos_company_website, :infos_company_logo, :infos_company_vat, :infos_company_email, :infos_company_pec)
    Setting.set('infos_company_name', p[:infos_company_name]) if p[:infos_company_name].present?
    Setting.set('infos_company_website', p[:infos_company_website]) if p[:infos_company_website].present?
    Setting.set('infos_company_vat', p[:infos_company_vat]) if p[:infos_company_vat].present?
    Setting.set('infos_company_email', p[:infos_company_email]) if p[:infos_company_email].present?
    Setting.set('infos_company_pec', p[:infos_company_pec]) if p[:infos_company_pec].present?
    Setting.set('infos_company_logo', p[:infos_company_logo], 'file') if p[:infos_company_logo].present?

    redirect_to settings_path
  end

  def edit_functionalities_action
    p = params.permit(:functionalities_task_acceptance)
    Setting.set('functionalities_task_acceptance', p[:functionalities_task_acceptance], 'boolean') if p[:functionalities_task_acceptance].present?

    redirect_to settings_path
  end

  def edit_vectorsearch_action
    p = params.permit(:vectorsearch_openai_key)
    Setting.set('vectorsearch_openai_key', p[:vectorsearch_openai_key]) if p[:vectorsearch_openai_key].present?

    redirect_to settings_path
  end

  def edit_slack_action
    p = params.permit(:slack_bot_user_oauth_token, :slack_verification_token)
    Setting.set('slack_bot_user_oauth_token', p[:slack_bot_user_oauth_token]) if p[:slack_bot_user_oauth_token].present?
    Setting.set('slack_verification_token', p[:slack_verification_token]) if p[:slack_verification_token].present?

    redirect_to settings_path
  end

  def reset_action
    Setting.reset("#{params[:key]}_")
    redirect_to settings_path
  end

  private

  def validate_policy_settings
    validate_policy!('settings')
  end
end
