# frozen_string_literal: true

# ToolsController.
class ToolsController < ApplicationController
  before_action :validate_session_user!
  before_action :validate_policy_tools
  before_action do
    @_navbar = "tools"
  end

  caches_action :index, cache_path: -> { current_cache_action_path }, layout: false
  def index
  end

  caches_action :projects_without_procedures, cache_path: -> { current_cache_action_path }, layout: false
  def projects_without_procedures
    @procedures = Procedure.all.not_as_model.resources_type_projects.order(name: :asc)
  end

  # NOTE: Cache disabled to solve some issues with layout that is not rendered correctly.
  # caches_action :projects_tasks_tracking, cache_path: -> { current_cache_action_path }, layout: false
  def projects_tasks_tracking
    @date_start = params[:date_start] ? Date.parse(params[:date_start]) : Date.today.at_beginning_of_month
    @date_end = params[:date_end] ? Date.parse(params[:date_end]) : Date.today.at_end_of_month
    @user_id = params[:user_id].blank? ? nil : params[:user_id]
    @user = User.find(@user_id) if @user_id

    if params[:project_id] && params[:procedure_id] && params[:procedure_status_id]
      @project = Project.find(params[:project_id])
      @procedure = @project.procedures.find(params[:procedure_id])
      @procedure_status = @procedure.procedures_statuses.find(params[:procedure_status_id])
      query = @procedure_status.procedures_items.resource_task.order(order: :asc)

      @procedure_items = []
      query.each do |item|
        task_tracks = Tasks::Track.where(task_id: item.resource_id, end_at: (@date_start..@date_end))
        task_tracks = task_tracks.where(user_id: @user_id) unless @user_id.blank?
        item.time_spent = task_tracks.sum(:time_spent)
        @procedure_items.push(item) if item.time_spent > 60
      end
      @total = @procedure_items.map(&:time_spent).sum
    elsif params[:project_id] && params[:procedure_id]
      @project = Project.find(params[:project_id])
      @procedure = @project.procedures.find(params[:procedure_id])
      query = @procedure.procedures_statuses.order(order: :asc)

      @procedure_statuses = []
      query.each do |status|
        tasks_ids = status.procedures_items.resource_task.pluck(:resource_id)
        task_tracks = Tasks::Track.where(task_id: tasks_ids, end_at: (@date_start..@date_end))
        task_tracks = task_tracks.where(user_id: @user_id) unless @user_id.blank?
        status.time_spent = task_tracks.sum(:time_spent)
        @procedure_statuses.push(status)
      end
      @total = @procedure_statuses.map(&:time_spent).sum
    elsif params[:project_id]
      @project = Project.find(params[:project_id])
      query = @project.procedures

      @project_procedures = []
      query.each do |procedure|
        tasks_ids = procedure.procedures_items.resource_task.pluck(:resource_id)
        task_tracks = Tasks::Track.where(task_id: tasks_ids, end_at: (@date_start..@date_end))
        task_tracks = task_tracks.where(user_id: @user_id) unless @user_id.blank?
        procedure.time_spent = task_tracks.sum(:time_spent)
        @project_procedures.push(procedure)
      end
      @total = @project_procedures.map(&:time_spent).sum
    else
      query = Project.joins(tasks: :tasks_tracks).where(tasks_tracks: { end_at: (@date_start..@date_end) })
      query = query.where(tasks_tracks: { user_id: @user_id }) unless @user_id.blank?
      @projects = query.select("projects.*, SUM(tasks_tracks.time_spent) AS time_spent").group("projects.id")
      @total = @projects.map(&:time_spent).sum
    end

    unless params[:print].blank?
      @_nav_title = "Esportazione attività"
      @_print_title = "Esportazione attività #{@date_start.strftime('%d/%m/%Y')} - #{@date_end.strftime('%d/%m/%Y')}"
      render :projects_tasks_tracking_print, layout: "application_print"
    end
  end

  private

  def validate_policy_tools
    validate_policy!("tools")
  end
end
