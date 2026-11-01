# frozen_string_literal: true

# ApplicationController.
# UI Edit variables:
# - @_navbar: navbar section name
# - @_flash_disabled: disable flash messages
class ApplicationController < ActionController::Base
  include ActionView::RecordIdentifier

  before_action :load_global_cache, except: [ :up, :serviceworker ]
  before_action :set_session_user_id, except: [ :up, :serviceworker ]
  skip_before_action :verify_authenticity_token, only: [ :up, :serviceworker ]

  def index
    return redirect_to(users_show_path(@session_user_id)) if @session_user_id
    User.any? ? redirect_to(authentication_login_path) : redirect_to(authentication_first_run_path)
  end

  def up
    render plain: "OK"
  end

  def serviceworker
    render action: "serviceworker", layout: false
  end

  def cacheclear
    # Clearing the cache also resets the login rate limit counters: admins only
    return unless validate_session_user!
    return unless validate_policy!("settings")

    Rails.cache.clear
    render plain: "Cache cleared"
  end

  # Called by an external scheduler. With JOBS_TOKEN set the caller must send it
  # (X-Jobs-Token header or token param); the semaphore is taken atomically
  # before running, so concurrent calls never run the jobs twice.
  def jobsrun
    jobs_token = ENV["JOBS_TOKEN"].to_s
    if jobs_token.present?
      given_token = (request.headers["X-Jobs-Token"] || params[:token]).to_s
      return head(:unauthorized) unless ActiveSupport::SecurityUtils.secure_compare(given_token, jobs_token)
    end

    jobs_semaphore_key = "ApplicationController/jobs_semaphore"
    if Rails.cache.write(jobs_semaphore_key, true, expires_in: 30.minutes, unless_exist: true)
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
    end

    render plain: "Jobs runned"
  rescue StandardError => e
    Rails.logger.error e
    Rails.logger.error e.backtrace.join("\n")
    render plain: "Jobs failed", status: 500
  end

  protected

  # Policies are part of the key: views render only what the user may use,
  # so a policy change must not serve a page built for the old set
  def current_cache_action_path
    policies_digest = Digest::MD5.hexdigest(@session_user&.cached_policies.to_a.sort.join(","))[0, 8]
    "#{Date.today.strftime('%Y%m%d-%H')}/#{@session_user_id}/#{policies_digest}#{request.fullpath}"
  end

  def validate_session_user_id!
    return true if @session_user_id

    sign_out
    redirect_to authentication_login_path(redirect: request.path)
    false
  end

  def validate_session_user!
    @session_user = User.find_by(id: @session_user_id) if @session_user_id
    # Cookies issued before a password change carry an old version: reject them
    return true if @session_user && @session_user.session_version == cookies.encrypted[:session_version].to_i

    @session_user = nil
    sign_out
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

  # httponly: scripts never read it; secure whenever the request came over HTTPS
  def sign_in(user)
    options = { expires: 1.month.from_now, httponly: true, secure: request.ssl? }
    cookies.encrypted[:user_id] = options.merge(value: user.id)
    cookies.encrypted[:session_version] = options.merge(value: user.session_version)
  end

  def sign_out
    cookies.delete(:user_id)
    cookies.delete(:session_version)
  end

  def query_projects_for_policy
    @query_projects_for_policy ||= @session_user.policy?("only_data_projects_as_member") ? Project.where(id: @session_user.projects_as_member_ids) : Project.all
  end

  # Tasks visibility for the web app, same rule as the API: with the membership
  # limit a user sees tasks of their projects plus tasks assigned to them
  def query_tasks_for_policy
    return Task.all unless @session_user.policy?("only_data_projects_as_member")

    Task.where(project_id: @session_user.projects_as_member_ids).or(Task.where(user_id: @session_user.id))
  end

  # Procedures visibility follows their project (global procedures stay visible)
  def query_procedures_for_policy
    return Procedure.all unless @session_user.policy?("only_data_projects_as_member")

    Procedure.where(project_id: @session_user.projects_as_member_ids).or(Procedure.where(project_id: nil))
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
