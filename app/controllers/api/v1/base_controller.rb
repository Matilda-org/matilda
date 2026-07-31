# frozen_string_literal: true

# Base controller for the JSON API (/api/v1).
# Requests authenticate with a per-user API key (X-API-Key header) so the same
# data access policies of the web app (Users::Policy) apply to the API surface.
class Api::V1::BaseController < ActionController::API
  before_action :authenticate_api_user!

  rescue_from ActiveRecord::RecordNotFound do
    render json: { error: "Risorsa non trovata" }, status: :not_found
  end
  rescue_from ActionController::ParameterMissing do |e|
    render json: { error: "Parametro mancante: #{e.param}" }, status: :bad_request
  end

  protected

  # Halt with 403 unless the authenticated user has the given policy.
  def require_policy!(policy)
    return true if @current_user.policy?(policy)

    render json: { error: "Permessi insufficienti (policy richiesta: #{policy})" }, status: :forbidden
    false
  end

  # Same project visibility rule used by the web app: users with the
  # only_data_projects_as_member policy only see projects they are members of.
  def query_projects_for_policy
    @query_projects_for_policy ||= limited_to_member_projects? ? Project.where(id: @current_user.projects_as_member_ids) : Project.all
  end

  # Tasks visibility: with the membership limit, a user sees tasks of their
  # projects plus tasks assigned to them (personal tasks have no project).
  def query_tasks_for_policy
    return Task.all unless limited_to_member_projects?

    Task.where(project_id: @current_user.projects_as_member_ids).or(Task.where(user_id: @current_user.id))
  end

  # Procedures visibility follows their project (global procedures stay visible).
  def query_procedures_for_policy
    return Procedure.all unless limited_to_member_projects?

    Procedure.where(project_id: @current_user.projects_as_member_ids).or(Procedure.where(project_id: nil))
  end

  def limited_to_member_projects?
    @current_user.policy?("only_data_projects_as_member")
  end

  # Paginate a query and render it as { data: [...], meta: {...} }.
  def render_paginated(query, as_json_options = {})
    page = params[:page]&.to_i || 1
    per_page = params[:per_page]&.to_i || 25
    per_page = 100 if per_page > 100

    records = query.page(page).per(per_page)
    render json: {
      data: records.as_json(as_json_options),
      meta: {
        page: page,
        per_page: per_page,
        total_count: records.total_count,
        total_pages: records.total_pages
      }
    }
  end

  def render_record_errors(record)
    render json: { errors: record.errors.full_messages }, status: :unprocessable_content
  end

  private

  def authenticate_api_user!
    api_key = request.headers["X-API-Key"].presence
    return render json: { error: "API key non fornita" }, status: :unauthorized if api_key.blank?

    @current_user = User.find_by(api_key: api_key)
    render json: { error: "API key non valida" }, status: :unauthorized unless @current_user
  end
end
