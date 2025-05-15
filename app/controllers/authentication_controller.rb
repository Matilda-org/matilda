# frozen_string_literal: true

# AuthenticationController.
class AuthenticationController < ApplicationController
  before_action :limit_requests!, only: %i[login_action recover_password_action update_password_action]
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
      flash[:danger] = 'Email o password non corretti'
      return redirect_to authentication_login_path(user_login_params.except(:password))
    end

    ApplicationMailer.login_success_mail(@user.email, request.remote_ip).deliver_now
    cookies.encrypted[:user_id] = { value: @user.id, expires: 1.month.from_now }
    redirect_to params[:redirect] || root_path
  end

  def recover_password; end

  def recover_password_action
    @user = User.find_by(params.permit(:email))

    unless @user
      flash[:danger] = 'Email non trovata'
      return redirect_to authentication_recover_password_path
    end

    code = SecureRandom.hex(4).upcase
    Rails.cache.write("AuthenticationController/recover_password/#{@user.id}", code, expires_in: 30.minutes)
    ApplicationMailer.recover_password_mail(@user.email, code).deliver_now

    redirect_to authentication_update_password_path(@user)
  end

  def update_password
    @user = User.find(params[:id])
  end

  def update_password_action
    @user = User.find(params[:id])
    code = Rails.cache.read("AuthenticationController/recover_password/#{@user.id}")

    unless code && params[:code] && code.upcase == params[:code].upcase
      flash[:danger] = 'Codice non corretto'
      return redirect_to authentication_update_password_path(@user)
    end

    unless @user.update(params.permit(:password, :password_confirmation))
      flash[:danger] = @user.errors.full_messages.join(', ')
      return redirect_to authentication_update_password_path(@user)
    end

    flash[:success] = 'Password aggiornata'
    redirect_to authentication_login_path
  end

  def logout
    cookies.encrypted[:user_id] = nil
    redirect_to root_path
  end

  private

  def user_login_params
    params.permit(:email, :password)
  end
end
