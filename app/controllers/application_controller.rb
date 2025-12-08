# frozen_string_literal: true

# ApplicationController.
# UI Edit variables:
# - @_navbar: navbar section name
# - @_flash_disabled: disable flash messages
class ApplicationController < ActionController::Base
  include ActionView::RecordIdentifier

  before_action :load_global_cache, except: :serviceworker
  before_action :set_session_user_id, except: :serviceworker
  skip_before_action :verify_authenticity_token, only: :serviceworker

  def index
    return redirect_to(users_show_path(@session_user_id)) if @session_user_id
    User.any? ? redirect_to(authentication_login_path) : redirect_to(authentication_first_run_path)
  end

  def serviceworker
    render action: "serviceworker", layout: false
  end

  def ping
    render plain: "Pong"
  end

  def cacheclear
    Rails.cache.clear
    render plain: "Cache cleared"
  end

  def jobsrun
    jobs_semaphore_key = "ApplicationController/jobs_semaphore"
    unless Rails.cache.read(jobs_semaphore_key)
      begin
        ActiveStorageCleanerJob.perform_now
      rescue StandardError => e
        Rails.logger.error e
      end
      begin
        TasksRepeatManagerJob.perform_now
      rescue StandardError => e
        Rails.logger.error e
      end
      begin
        NotificationsManagerJob.perform_now
      rescue StandardError => e
        Rails.logger.error e
      end
      Rails.cache.write(jobs_semaphore_key, true, expires_in: 30.minutes)
    end

    render plain: "Jobs runned"
  rescue StandardError => e
    Rails.logger.error e
    Rails.logger.error e.backtrace.join("\n")
    render plain: "Jobs failed", status: 500
  end

  protected

  def current_cache_action_path
    "#{Date.today.strftime('%Y%m%d-%H')}/#{@session_user_id}#{request.fullpath}"
  end

  def validate_session_user_id!
    return true if @session_user_id

    cookies.encrypted[:user_id] = nil
    redirect_to authentication_login_path(redirect: request.path)
    false
  end

  def validate_session_user!
    return true if @session_user_id && @session_user = User.find_by(id: @session_user_id)

    cookies.encrypted[:user_id] = nil
    redirect_to authentication_login_path(redirect: request.path)
    false
  end

  def validate_policy!(policy)
    return true if @session_user&.policy?(policy)

    redirect_to root_path
    false
  end

  def limit_requests!(limit = 5, period = 600)
    log_key = "ApplicationController/limit_requests/#{request.remote_ip}/#{controller_name}/#{action_name}"
    log = Rails.cache.read(log_key)
    Rails.cache.write(log_key, (log&.to_i || 0) + 1, expires_in: period)

    return unless log
    return if log <= limit

    Rails.logger.info("Too many requests from #{request.remote_ip} for #{controller_name}##{action_name}")
    flash[:danger] = "L'operazione richiesta è stata eseguita per un numero eccessivo di volte. Attendi #{period / 60} minuti e riprova."
    redirect_to root_path
  end

  def load_global_cache
    @global_cache ||= GlobalCache.new
  end

  def set_session_user_id
    @session_user_id = cookies.encrypted[:user_id]
  end

  def query_projects_for_policy
    @query_projects_for_policy ||= @session_user.policy?("only_data_projects_as_member") ? Project.where(id: @session_user.projects_as_member_ids) : Project.all
  end

  def paginate_query(query)
    page = params[:page]&.to_i || 1
    per_page = params[:per_page]&.to_i || 24
    per_page = 100 if per_page > 100

    query.page(page).per(per_page)
  end

  def create_procedure_item(resource_id)
    return if params[:procedures_status_id].blank?

    procedure_status = Procedures::Status.find_by(id: params[:procedures_status_id])
    return unless procedure_status

    procedure_status.procedure.procedures_items.create(params.permit(:procedures_status_id).merge(resource_id: resource_id))
  end
end
