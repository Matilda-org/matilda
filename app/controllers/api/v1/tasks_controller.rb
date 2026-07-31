# frozen_string_literal: true

# Tasks API: read and manage tasks (same policies as the web app).
class Api::V1::TasksController < Api::V1::BaseController
  # GET /api/v1/tasks
  def index
    return unless require_policy!("tasks_index")

    tasks = query_tasks_for_policy.order(deadline: :desc)
    tasks = tasks.where(user_id: params[:user_id]) if params[:user_id].present?
    tasks = tasks.where(project_id: params[:project_id]) if params[:project_id].present?
    tasks = tasks.where(completed: params[:completed] == "true") if params[:completed].present?
    tasks = tasks.where.not(deadline: nil) if params[:with_deadline].present?
    tasks = tasks.where(deadline: Date.parse(params[:deadline_from])..) if params[:deadline_from].present?
    tasks = tasks.where(deadline: ..Date.parse(params[:deadline_to])) if params[:deadline_to].present?
    tasks = tasks.search(params[:search]) if params[:search].present?
    render_paginated(tasks)
  rescue Date::Error
    render json: { error: "Formato data non valido (atteso YYYY-MM-DD)" }, status: :bad_request
  end

  # GET /api/v1/tasks/:id
  def show
    return unless require_policy!("tasks_show")

    render json: task_finder.as_json(
      include: [ :user, :project, :tasks_tracks, :tasks_followers, :tasks_checks, :tasks_comments ],
      with_content: true
    )
  end

  # POST /api/v1/tasks
  def create
    return unless require_policy!("tasks_create")

    task = Task.new(task_params)
    # same acceptance flow of the web app: without the acceptance policy new tasks start unaccepted
    task.accepted = false if Setting.get("functionalities_task_acceptance") && !@current_user.policy?("tasks_acceptance")
    return render_record_errors(task) unless task.save

    render json: task.as_json(with_content: true), status: :created
  end

  # PATCH /api/v1/tasks/:id
  def update
    return unless require_policy!("tasks_edit")

    task = task_finder
    return render_record_errors(task) unless task.update(task_params)

    render json: task.as_json(with_content: true)
  end

  # DELETE /api/v1/tasks/:id
  def destroy
    return unless require_policy!("tasks_destroy")

    task_finder.destroy
    head :no_content
  end

  # POST /api/v1/tasks/:id/complete
  def complete
    return unless require_policy!("tasks_complete")

    task = task_finder
    return render_record_errors(task) unless task.update(completed: true, completed_at: Time.now)

    render json: task.as_json
  end

  # POST /api/v1/tasks/:id/uncomplete
  def uncomplete
    return unless require_policy!("tasks_uncomplete")

    task = task_finder
    return render_record_errors(task) unless task.update(completed: false, completed_at: nil)

    render json: task.as_json
  end

  # POST /api/v1/tasks/:id/comments
  def create_comment
    return unless require_policy!("tasks_comment")

    comment = task_finder.tasks_comments.build(params.permit(:content, :service))
    comment.user_id = @current_user.id
    return render_record_errors(comment) unless comment.save

    render json: comment.as_json, status: :created
  end

  private

  # Find the task through the policy-scoped query so limited users
  # can't read or touch tasks outside their projects (404 otherwise).
  def task_finder
    query_tasks_for_policy.find(params[:id])
  end

  def task_params
    params.permit(
      :title, :content, :deadline, :time_estimate, :user_id, :project_id,
      :repeat, :repeat_type, :repeat_from, :repeat_to, :repeat_monthday,
      repeat_weekdays: []
    )
  end
end
