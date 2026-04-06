# frozen_string_literal: true

# ApisController.
class ApisController < ActionController::Base
  # Disabilito la protezione CSRF per le API
  skip_before_action :verify_authenticity_token

  # Forzo formato JSON per le API
  before_action :force_json_format

  # Verifica che la API key sia corretta
  before_action :validate_api_key

  # Procedures
  ##

  def procedure
    @procedure = Procedure.find(params[:id])
    render json: @procedure.as_json(include: [ :procedures_statuses, :procedures_items, :projects_items, :tasks_items, :project ])
  end

  # Tasks
  ##

  def tasks
    @tasks = Task.all
    # apply filters
    @tasks = @tasks.where(user_id: params[:user_id]) if params[:user_id].present?
    @tasks = @tasks.where(completed: params[:completed]) if params[:completed].present?
    @tasks = @tasks.where.not(deadline: nil) if params[:with_deadline].present?
    # render only the 100 most recent tasks to avoid performance issues
    @tasks = @tasks.order(deadline: :desc).limit(100)
    render json: @tasks.as_json
  end

  def task
    @task = Task.find(params[:id])
    render json: @task.as_json(include: [ :user, :project, :procedures_items, :procedures_as_item, :tasks_tracks, :tasks_followers, :tasks_checks, :tasks_comments ], with_content: true)
  end

  def task_comment
    @task = Task.find(params[:id])
    @comment = @task.tasks_comments.new(params.permit(:content, :service))
    if @comment.save
      render json: {}
    else
      render json: { errors: @comment.errors.full_messages }, status: :unprocessable_content
    end
  end

  def task_update
    @task = Task.find(params[:id])
    if @task.update(task_params)
      render json: {}
    else
      render json: { errors: @task.errors.full_messages }, status: :unprocessable_content
    end
  end

  # Private
  ##

  private

  def task_params
    params.require(:task).permit(:title)
  end

  def force_json_format
    request.format = :json
  end

  def validate_api_key
    settings_api_key = Setting.get("functionalities_api_key")
    request_api_key = request.headers["X-API-Key"] || params[:api_key]

    if settings_api_key.blank?
      render json: { error: "API key non configurata" }, status: :unauthorized
      return
    end

    if request_api_key.blank?
      render json: { error: "API key non fornita" }, status: :unauthorized
      return
    end

    if request_api_key != settings_api_key
      render json: { error: "API key non valida" }, status: :unauthorized
      return
    end

    true
  end
end
