# frozen_string_literal: true

# AuthenticationController.
class AuthenticationController < ApplicationController
  before_action :limit_requests!, only: %i[login_action recover_password_action update_password_action first_run_action]
  before_action do
    @_flash_disabled = true
    @_navbar_disabled = true
    @_authentication = true
  end

  def login
    @user = User.new(user_login_params)
    @redirect = params[:redirect]
  end

  def login_action
    @user = User.find_by(user_login_params.except(:password))

    unless @user&.authenticate(user_login_params[:password])
      flash[:danger] = "Email o password non corretti"
      return redirect_to authentication_login_path(user_login_params.except(:password))
    end

    ApplicationMailer.login_success_mail(@user.email, request.remote_ip).deliver_now
    sign_in(@user)
    # url_from drops anything pointing to another host
    redirect_to url_from(params[:redirect]) || root_path
  end

  def recover_password; end

  # The reset page is addressed by an opaque token, never by the user id, and
  # unknown emails get the same answer: nobody can probe which accounts exist.
  def recover_password_action
    token = SecureRandom.urlsafe_base64(24)
    user = User.find_by(params.permit(:email))

    if user
      code = SecureRandom.hex(4).upcase
      Rails.cache.write(recover_password_cache_key(token), { user_id: user.id, code: code }, expires_in: 30.minutes)
      ApplicationMailer.recover_password_mail(user.email, code).deliver_now
    end

    flash[:success] = "Se l'email è registrata riceverai un codice per aggiornare la password"
    redirect_to authentication_update_password_path(token)
  end

  def update_password
    @token = params[:id]
  end

  def update_password_action
    @token = params[:id]
    recovery = Rails.cache.read(recover_password_cache_key(@token))
    @user = User.find_by(id: recovery[:user_id]) if recovery

    unless @user && ActiveSupport::SecurityUtils.secure_compare(recovery[:code], params[:code].to_s.upcase)
      flash[:danger] = "Codice non corretto"
      return redirect_to authentication_update_password_path(@token)
    end

    unless @user.update(params.permit(:password, :password_confirmation))
      flash[:danger] = @user.errors.full_messages.join(", ")
      return redirect_to authentication_update_password_path(@token)
    end

    # single use: the code dies with the first successful reset
    Rails.cache.delete(recover_password_cache_key(@token))
    flash[:success] = "Password aggiornata"
    redirect_to authentication_login_path
  end
  def logout
    sign_out
    redirect_to root_path
  end

  def first_run
    return redirect_to root_path if User.any?
    @user = User.new(user_first_run_params)
  end

  def first_run_action
    return redirect_to root_path if User.any?

    @user = User.new(user_first_run_params)

    unless @user.save
      flash[:danger] = @user.errors.full_messages.join(", ")
      return redirect_to authentication_first_run_path(user_first_run_params)
    end

    @user.update_policies(Users::Policy.policies.keys.reject { |key| key == "only_data_projects_as_member" })
    sign_in(@user)

    begin
      require "rake"
      Rails.application.load_tasks
      Rake::Task["create_default_data"].invoke
    rescue StandardError => e
      Rails.logger.error "Error while creating default data: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
    end

    redirect_to root_path
  end

  private

  def recover_password_cache_key(token)
    "AuthenticationController/recover_password/#{token}"
  end

  def user_first_run_params
    params.permit(:name, :surname, :email, :password, :password_confirmation)
  end

  def user_login_params
    params.permit(:email, :password)
  end
end
