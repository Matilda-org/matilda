# frozen_string_literal: true

# TasksController.
class TasksController < ApplicationController
  before_action :validate_session_user!
  before_action do
    @_navbar = "tasks"

    Tasks::Track.not_closed.find_in_batches do |tracks|
      tracks.each { |t| t.close(true) }
    end
  end

  def resume_per_inputdate
    month = params[:month] || Date.today.month
    year = params[:year] || Date.today.year

    begin_month = Date.new(year.to_i, month.to_i, 1)
    end_month = begin_month.end_of_month
    tasks = Task.not_completed.where("deadline >= ? AND deadline <= ?", begin_month, end_month)

    data = {}
    tasks.each do |task|
      data[task.deadline.strftime("%Y-%m-%d")] ||= 0
      data[task.deadline.strftime("%Y-%m-%d")] += 1
    end

    final_data = []
    data.each do |date, count|
      date_obj = Date.parse(date)
      color = "danger" if date_obj < Date.today
      color = "warning" if date_obj == Date.today
      color = "info" if date_obj > Date.today

      final_data << {
        date: date,
        count: count,
        color: color
      }
    end

    render json: final_data
  end

  caches_action :index, cache_path: -> { current_cache_action_path }, layout: false
  def index
    return unless validate_policy!("tasks_index")
    @mode = params[:mode] || "calendar"

    if @mode == "people"
      @date = params[:date] ? Date.parse(params[:date]) : Date.today
      @project_id = params[:project_id]

      tasks = Task.where(deadline: @date).or(Task.where(deadline: nil).where.not(user_id: nil))
      tasks = tasks.where(project_id: @project_id) unless @project_id.blank?
      tasks = tasks.order(deadline: :asc, title: :asc)
      @tasks_per_user = tasks.group_by(&:user_id)
      render :index_people
    else
      @date_start = params[:date_start] ? Date.parse(params[:date_start]) : Date.today.at_beginning_of_week
      @date_end = params[:date_end] ? Date.parse(params[:date_end]) : Date.today.at_end_of_week
      @date_end = @date_start if @date_end < @date_start
      @user_id = params[:user_id]
      @project_id = params[:project_id]

      tasks = Task.where(deadline: (@date_start..@date_end)).includes(:tasks_checks)
      tasks = tasks.where(user_id: @user_id) unless @user_id.blank?
      tasks = tasks.where(project_id: @project_id) unless @project_id.blank?
      @tasks_per_date = tasks.group_by(&:deadline)
    end
  end

  caches_action :show, cache_path: -> { current_cache_action_path }, layout: false
  def show
    return unless validate_policy!("tasks_show")

    nil unless task_finder
  end

  caches_action :actions, cache_path: -> { current_cache_action_path }, layout: false
  def actions
    @type = params[:type]
    @task = params[:id].present? ? Task.find(params[:id]) : Task.new

    @projects_for_position = query_projects_for_policy.not_archived.order(name: :asc)

    return render "tasks/actions/create" if @type == "create"
    return render "tasks/actions/edit" if @type == "edit"
    return render "tasks/actions/show" if @type == "show"
    return render "tasks/actions/destroy" if @type == "destroy"
    return render "tasks/actions/complete" if @type == "complete"
    return render "tasks/actions/postpone" if @type == "postpone"
    return render "tasks/actions/uncomplete" if @type == "uncomplete"

    render partial: "shared/action-error"
  end

  def create_action
    return unless validate_policy!("tasks_create")

    @task = Task.new(task_params)
    @task.accepted = false if Setting.get("functionalities_task_acceptance") && !@session_user.policy?("tasks_acceptance")
    return render "tasks/actions/create" unless @task.save

    create_procedure_item(@task.id)
    render partial: "shared/action-feedback", locals: {
      title: "Nuovo task",
      turbo_frame: params[:turbo_frame_key] || "_top",
      feedback_args: {
        title: "Task creato",
        subtitle: "Il task è stato creato con successo.",
        render_content: "tasks/shared/card",
        render_content_args: { task: @task },
        type: "success"
      }
    }
  end

  def edit_action
    return unless validate_policy!("tasks_edit")
    return unless task_finder

    return render "tasks/actions/edit" unless @task.update(task_params)
    @task.update(accepted: true) if @session_user.policy?("tasks_acceptance") && !@task.accepted

    render partial: "shared/action-feedback", locals: {
      title: "Modifica task",
      turbo_frame: params[:turbo_frame_key] || "_top",
      feedback_args: {
        title: "Task aggiornato",
        subtitle: "Il task è stato aggiornato con successo.",
        render_content: "tasks/shared/card",
        render_content_args: { task: @task },
        type: "success"
      }
    }
  end

  def destroy_action
    return unless validate_policy!("tasks_destroy")
    return unless task_finder

    @task.destroy

    render partial: "shared/action-feedback", locals: {
      title: "Elimina task",
      turbo_frame: params[:turbo_frame_key] || "_top",
      feedback_args: {
        title: "Task eliminato",
        subtitle: "Il task #{@task.title} è stato eliminato.",
        type: "success"
      }
    }
  end

  def complete_action
    return unless validate_policy!("tasks_complete")
    return unless task_finder

    return render "tasks/actions/complete" unless @task.update(completed: true, completed_at: Time.now)

    render partial: "shared/action-feedback", locals: {
      title: "Completa task",
      turbo_frame: params[:turbo_frame_key] || "_top",
      feedback_args: {
        title: "Task completato",
        subtitle: "Il task è stato completato.",
        render_content: "tasks/shared/card",
        render_content_args: { task: @task },
        type: "success"
      }
    }
  end

  def postpone_action
    return unless validate_policy!("tasks_edit")
    return unless task_finder

    deadline = Date.tomorrow
    deadline = @task.deadline + 1.day if @task.deadline.present? && @task.deadline > Date.today

    return render "tasks/actions/postpone" unless @task.update(deadline: deadline)

    render partial: "shared/action-feedback", locals: {
      title: "Rimanda task",
      turbo_frame: params[:turbo_frame_key] || "_top",
      feedback_args: {
        title: "Task rimandato",
        subtitle: "Il task è stato rimandato al #{deadline.strftime('%d/%m/%Y')}.",
        render_content: "tasks/shared/card",
        render_content_args: { task: @task },
        type: "success"
      }
    }
  end

  def uncomplete_action
    return unless validate_policy!("tasks_uncomplete")
    return unless task_finder

    return render "tasks/actions/uncomplete" unless @task.update(completed: false, completed_at: nil)

    render partial: "shared/action-feedback", locals: {
      title: "Attiva task",
      turbo_frame: params[:turbo_frame_key] || "_top",
      feedback_args: {
        title: "Task attivato",
        subtitle: "Il task è stato attivato.",
        render_content: "tasks/shared/card",
        render_content_args: { task: @task },
        type: "success"
      }
    }
  end

  # Tracks
  ################################################################################

  def start_track_action
    return unless validate_policy!("tasks_track")
    return unless task_finder

    # close old tracks for user
    @session_user.tasks_tracks.not_closed.each(&:close)

    # create new track
    track = @task.tasks_tracks.create(user_id: @session_user_id)

    render partial: "tasks/tracker", locals: { track: track }
  end

  def ping_track_action
    return unless validate_policy!("tasks_track")
    return unless task_finder
    return unless tasks_track_finder

    @track.update(ping_at: Time.now)

    render json: {}
  end

  def end_track_action
    return unless validate_policy!("tasks_track")
    return unless task_finder
    return unless tasks_track_finder

    @track.close

    render partial: "tasks/tracker", locals: { track: @track }
  end

  # Checks
  ################################################################################

  def toggle_check_action
    return unless validate_policy!("tasks_check")
    return unless task_finder

    check = @task.tasks_checks.find_or_initialize_by(id: params[:check_id])
    check.checked = !check.checked
    check.save

    render partial: "tasks/shared/checks", locals: { task: @task, frame_id: params[:frame_id] }
  end

  private

  def task_params
    params.permit(
      :title, :content, :deadline, :time_estimate, :user_id,
      :position_procedure_id,
      :repeat, :repeat_type, :repeat_from, :repeat_to, :repeat_monthday, repeat_weekdays: [],
      tasks_followers_user_ids: [],
      tasks_checks_texts: [],
    )
  end

  def task_finder
    @task = Task.find_by(id: params[:id])
    unless @task
      flash[:danger] = "Task non trovato"
      redirect_to tasks_path
      return false
    end

    true
  end

  def tasks_track_finder
    @track = @task.tasks_tracks.find_by(id: params[:track_id])
    unless @track
      flash[:danger] = "Track non trovato"
      redirect_to tasks_show_path(@task)
      return false
    end

    true
  end
end
