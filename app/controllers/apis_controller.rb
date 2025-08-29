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

  def task
    @task = Task.find(params[:id])
    render json: @task.as_json(include: [ :user, :project, :procedures_items, :procedures_as_item, :tasks_tracks, :tasks_followers, :tasks_checks ])
  end

  def task_update
    @task = Task.find(params[:id])
    if @task.update(task_params)
      render json: {}
    else
      render json: { errors: @task.errors.full_messages }, status: :unprocessable_entity
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
    request_api_key = request.headers["X-API-Key"]

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
