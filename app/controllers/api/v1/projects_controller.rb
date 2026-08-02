# frozen_string_literal: true

# Projects API: read access to projects and their logs, creation.
class Api::V1::ProjectsController < Api::V1::BaseController
  # POST /api/v1/projects
  def create
    return unless require_policy!("projects_create")

    project = Project.new(params.permit(:code, :name, :year, :description, :budget_management, :budget_money, :budget_time))
    project.year ||= Date.today.year
    return render_record_errors(project) unless project.save

    render json: project.as_json, status: :created
  end

  # GET /api/v1/projects
  def index
    return unless require_policy!("projects_index")

    projects = query_projects_for_policy.order(name: :asc)
    projects = projects.not_archived unless params[:archived].present?
    projects = projects.archived if params[:archived].present?
    projects = projects.search(params[:search]) if params[:search].present?
    render_paginated(projects)
  end

  # GET /api/v1/projects/:id
  def show
    return unless require_policy!("projects_show")

    project = query_projects_for_policy.find(params[:id])
    render json: project.as_json(include: [ :projects_members, :projects_attachments, :projects_repositories, :procedures ])
  end

  # GET /api/v1/projects/:id/logs
  def logs
    return unless require_policy!("projects_show")

    project = query_projects_for_policy.find(params[:id])
    render_paginated(project.projects_logs.order(created_at: :desc))
  end
end
