# frozen_string_literal: true

# TasksController.
class TasksController < ApplicationController
  # Fields the task detail can edit inline (update_field_action)
  INLINE_FIELDS = %w[title deadline user_id time_estimate].freeze

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
    load_filter_options

    if @mode == "people"
      load_people_grouping
      render :index_people
    else
      load_calendar_grouping
    end
  end

  # Drag & drop from the calendar/people boards: dropping a task on another column
  # changes its deadline (calendar) or its assignee (people). Only the affected
  # columns are re-rendered (source + target) so the board controller stays mounted
  # and headers/counters stay in sync.
  def move_action
    return unless validate_policy!("tasks_edit")
    return unless task_finder

    if params[:mode] == "people"
      old_user_id = @task.user_id
      @task.update(user_id: params[:assignee_id].presence)
      load_people_grouping
      affected = [ old_user_id, @task.user_id ].uniq
      render turbo_stream: affected.map { |user_id| people_status_stream(user_id) }
    else
      old_deadline = @task.deadline
      deadline = safe_date(params[:deadline], nil)
      @task.update(deadline: deadline) if deadline
      load_calendar_grouping
      # dates before the visible week live in the overdue column, which is always
      # re-rendered: a task may leave it, or be dropped on it (a no-op move)
      affected = [ old_deadline, @task.deadline ].compact.uniq.select { |date| date >= @date_start }
      render turbo_stream: [ calendar_overdue_stream ] + affected.map { |date| calendar_status_stream(date) }
    end
  end

  caches_action :show, cache_path: -> { current_cache_action_path }, layout: false
  def show
    return unless validate_policy!("tasks_show")

    nil unless task_finder
  end

  # Gate the modal dispatcher before caches_action, so cached responses are gated too
  before_action -> { validate_policy!("tasks_show") }, only: :actions
  caches_action :actions, cache_path: -> { current_cache_action_path }, layout: false
  def actions
    @type = params[:type]
    @task = params[:id].present? ? query_tasks_for_policy.find(params[:id]) : Task.new
    @task = build_duplicated_task(params[:duplicate_id]) if @type == "create" && params[:duplicate_id].present?

    @projects_for_position = query_projects_for_policy.not_archived.order(name: :asc)
    return render "tasks/actions/create" if @type == "create"
    return render "tasks/actions/edit" if @type == "edit"
    return render "tasks/actions/show" if @type == "show"
    return render "tasks/actions/destroy" if @type == "destroy"
    return render "tasks/actions/complete" if @type == "complete"
    return render "tasks/actions/postpone" if @type == "postpone"
    return render "tasks/actions/uncomplete" if @type == "uncomplete"
    return render "tasks/actions/add-track" if @type == "add-track"

    render partial: "shared/action-error"
  end

  def create_action
    return unless validate_policy!("tasks_create")

    @task = Task.new(task_params)
    @task.accepted = false if Setting.get("functionalities_task_acceptance") && !@session_user.policy?("tasks_acceptance")
    @projects_for_position = query_projects_for_policy.not_archived.order(name: :asc)
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

    @projects_for_position = query_projects_for_policy.not_archived.order(name: :asc)
    return render "tasks/actions/edit" unless update_task(task_params)

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

  # Click-to-edit on the task detail: saves a single whitelisted field and answers
  # with its turbo-frame, re-rendered as text (or still open with the error).
  def update_field_action
    return unless validate_policy!("tasks_edit")
    return unless task_finder

    field = params[:field].to_s
    frame = params[:frame].to_s[/\A\h{1,16}\z/]
    return head :bad_request unless INLINE_FIELDS.include?(field) && frame

    value = params[:value].to_s
    error = inline_field_error(field, value)
    if error.nil? && !update_task(field => value.presence)
      error = (@task.errors.messages_for(field).presence || @task.errors.full_messages).to_sentence.upcase_first
      @task.restore_attributes
    end

    locals = { task: @task, field: field, frame: frame }
    return render partial: "tasks/shared/inline-field", locals: locals.merge(focus: true) unless error

    render partial: "tasks/shared/inline-field", locals: locals.merge(value: value, error: error), status: :unprocessable_entity
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
        undo: { label: "Annulla", href: tasks_uncomplete_action_path(@task, turbo_frame_key: params[:turbo_frame_key]) },
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

    unless @track.end_at.blank?
      render json: { error: "Track already ended" }, status: 422
      return
    end

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

  def add_track_action
    return unless validate_policy!("tasks_track")
    return unless task_finder

    date = safe_date(params[:date], Date.today)
    duration =
      if params[:duration] == "custom"
        # base 10 so "08"/"09" are not parsed as octal; nil on anything non-numeric
        hours = Integer(params[:hours].to_s.presence || "0", 10, exception: false)
        minutes = Integer(params[:minutes].to_s.presence || "0", 10, exception: false)
        hours && minutes && hours >= 0 && minutes.between?(0, 59) ? (hours * 3600) + (minutes * 60) : 0
      else
        params[:duration].to_i
      end

    unless duration.between?(1, 24 * 3600)
      @duration_error = "Inserisci una durata valida, da 1 minuto a 24 ore."
      return render "tasks/actions/add-track", status: :unprocessable_content
    end

    begin
      @task.add_manual_track!(user: @session_user, date: date, duration: duration)
    rescue StandardError => e
      Rails.logger.error e
      flash.now[:danger] = "Non è stato possibile aggiungere il tempo. Seleziona un giorno e una durata validi."
      return render "tasks/actions/add-track", status: :unprocessable_content
    end

    render partial: "shared/action-feedback", locals: {
      title: "Aggiungi tempo",
      turbo_frame: params[:turbo_frame_key] || "_top",
      feedback_args: {
        title: "Tempo aggiunto",
        subtitle: "Registrati #{helpers.track_time(duration)} di lavoro per il #{date.strftime('%d/%m/%Y')}.",
        render_content: "tasks/shared/card",
        render_content_args: { task: @task },
        type: "success"
      }
    }
  end

  def tracks
    return unless validate_policy!("tasks_index")

    project_param = params[:project_id].presence
    task_param = params[:task_id].presence

    @task = query_tasks_for_policy.find_by(id: task_param) if task_param
    # if a project is explicitly chosen and the task is not in it, drop the task filter
    @task = nil if @task && project_param && @task.project_id.to_s != project_param

    @project_id = project_param || @task&.project_id
    @project = query_projects_for_policy.find_by(id: @project_id) if @project_id

    @date = Date.parse(params[:date]) if params[:date].present? rescue nil

    tracks = Tasks::Track.includes(:user, task: :project).order(start_at: :desc)

    if @session_user.policy?("only_data_projects_as_member")
      accessible_task_ids = Task.where(project_id: @session_user.projects_as_member_ids).select(:id)
      tracks = tracks.where(task_id: accessible_task_ids)
    end

    if @task
      tracks = tracks.where(task_id: @task.id)
    elsif @project
      tracks = tracks.where(task_id: @project.tasks.select(:id))
    end

    tracks = tracks.where(start_at: @date.all_day) if @date

    @total = tracks.sum(:time_spent)
    @tracks = paginate_query(tracks)
  end

  def destroy_track_action
    return unless validate_policy!("tasks_track")
    return redirect_to tasks_tracks_path unless manageable_track_finder

    @track.destroy_with_time_rollback!

    redirect_to tracks_path_with_current_filters
  end

  # Move an existing track to another day, keeping time of day and duration.
  # Future days are allowed on purpose (planned work).
  def update_track_date_action
    return unless validate_policy!("tasks_track")
    return redirect_to tasks_tracks_path unless manageable_track_finder

    date = safe_date(params[:date], nil)
    if date.nil?
      flash[:danger] = "Data non valida"
    else
      begin
        @track.move_to_date!(date)
      rescue StandardError => e
        Rails.logger.error e
        flash[:danger] = "Non è stato possibile aggiornare la data del tracking"
      end
    end

    redirect_to tracks_path_with_current_filters
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

  # Comments
  ################################################################################

  def create_comment_action
    return unless validate_policy!("tasks_comment")
    return unless task_finder

    @comment = @task.tasks_comments.build(comment_params)
    @comment.user_id = @session_user_id
    return render partial: "tasks/shared/comments", locals: { task: @task } if @comment.save

    # Keep the draft in the composer so a failed save never loses the text
    render partial: "tasks/shared/comments",
           locals: { task: @task, draft: @comment.content, error: @comment.errors.full_messages.to_sentence },
           status: :unprocessable_entity
  end

  def destroy_comment_action
    return unless validate_policy!("tasks_comment")
    return unless task_finder

    comment = @task.tasks_comments.find_by(id: params[:comment_id])
    comment.destroy if comment&.deletable_by?(@session_user_id)

    render partial: "tasks/shared/comments", locals: { task: @task }
  end

  private

  # Shared by the edit form and the inline editor, so both trigger the same side effects
  def update_task(attributes)
    return false unless @task.update(attributes)

    @task.update(accepted: true) if @session_user.policy?("tasks_acceptance") && !@task.accepted
    true
  end

  # Values the model would silently cast to nil (bad date, unknown user/estimate) are rejected here
  def inline_field_error(field, value)
    return if value.blank?

    case field
    when "deadline"
      "Data non valida" unless iso_date?(value)
    when "user_id"
      "Utente non valido" unless User.exists?(id: value)
    when "time_estimate"
      "Stima non valida" unless Task::TIME_ESTIMATE_OPTIONS.any? { |_label, seconds| seconds.to_s == value }
    end
  end

  def iso_date?(value)
    Date.iso8601(value)
    true
  rescue Date::Error
    false
  end

  def task_params
    params.permit(
      :title, :content, :deadline, :time_estimate, :user_id,
      :position_procedure_id,
      :repeat, :repeat_type, :repeat_from, :repeat_to, :repeat_monthday,
      repeat_weekdays: [],
      tasks_followers_user_ids: [],
      tasks_checks_texts: [],
    )
  end

  def comment_params
    params.permit(:content)
  end

  # build an unsaved task pre-filled with the data of an existing one, so the
  # create form can be opened as a "duplicate"
  def build_duplicated_task(source_id)
    source = query_tasks_for_policy.find(source_id)
    task = Task.new(
      title: source.title,
      deadline: source.deadline,
      time_estimate: source.time_estimate,
      user_id: source.user_id,
      repeat: source.repeat,
      repeat_type: source.repeat_type,
      repeat_from: source.repeat_from,
      repeat_to: source.repeat_to,
      repeat_monthday: source.repeat_monthday,
      repeat_weekdays: source.repeat_weekdays,
    )
    task.content = source.content.body.to_trix_html if source.content&.body.present?
    task.tasks_checks_texts = source.tasks_checks_texts
    task.tasks_followers_user_ids = source.tasks_followers_user_ids
    task.position_procedure_id = source.procedure_as_item&.id
    task
  end

  # safely parse a date param, falling back when the value is missing or malformed
  def safe_date(value, fallback)
    value.present? ? Date.parse(value) : fallback
  rescue ArgumentError, TypeError
    fallback
  end

  # Build @tasks_per_date for the calendar board from the current filters.
  def load_calendar_grouping
    @date_start = safe_date(params[:date_start], Date.today.at_beginning_of_week)
    @date_end = safe_date(params[:date_end], Date.today.at_end_of_week)
    @date_end = @date_start if @date_end < @date_start
    @user_id = params[:user_id]
    @project_id = params[:project_id]

    tasks = query_tasks_for_policy.includes(:tasks_checks)
    tasks = tasks.where(user_id: @user_id) unless @user_id.blank?
    tasks = tasks.where(project_id: @project_id) unless @project_id.blank?
    @tasks_per_date = tasks.where(deadline: (@date_start..@date_end)).group_by(&:deadline)
    # unfinished tasks due before the visible week, shown in the fixed "Scaduti" column
    @overdue_tasks = tasks.not_completed.where(deadline: ...@date_start).order(deadline: :asc, title: :asc).to_a
  end

  def calendar_move_context
    { mode: "calendar", date_start: @date_start, date_end: @date_end, user_id: @user_id, project_id: @project_id }
  end

  # Turbo Stream to replace a single calendar day column with its current tasks.
  def calendar_status_stream(date)
    turbo_stream.replace(
      "tasks-calendar-status-#{date.strftime('%Y-%m-%d')}",
      partial: "tasks/calendar-status",
      locals: { date: date, tasks: @tasks_per_date[date] || [], move_context: calendar_move_context }
    )
  end

  # Turbo Stream to replace the fixed "Scaduti" column of the calendar board.
  def calendar_overdue_stream
    turbo_stream.replace(
      "tasks-calendar-status-overdue",
      partial: "tasks/calendar-status",
      locals: { date: @date_start, tasks: @overdue_tasks, move_context: calendar_move_context, overdue: true }
    )
  end

  # Turbo Stream to replace a single people column with its current tasks.
  def people_status_stream(user_id)
    move_context = { mode: "people", date: @date, project_id: @project_id }
    turbo_stream.replace(
      "tasks-people-status-#{user_id}",
      partial: "tasks/people-status",
      locals: { user: user_id ? User.find_by(id: user_id) : nil, tasks: @tasks_per_user[user_id] || [], move_context: move_context }
    )
  end

  # Build @tasks_per_user for the people board from the current filters.
  def load_filter_options
    @filter_projects = query_projects_for_policy.not_archived.order(year: :asc, name: :asc).pluck(:name, :id)
    @filter_users = User.order(surname: :asc, name: :asc).map { |u| [ u.complete_name, u.id ] }
  end

  def load_people_grouping
    @date = safe_date(params[:date], Date.today)
    @project_id = params[:project_id]

    tasks = query_tasks_for_policy.and(Task.where(deadline: @date).or(Task.where(deadline: nil, completed: false).where.not(user_id: nil)))
    tasks = tasks.where(project_id: @project_id) unless @project_id.blank?
    tasks = tasks.order(deadline: :asc, title: :asc).includes(:tasks_checks)
    @tasks_per_user = tasks.group_by(&:user_id)
  end

  def task_finder
    @task = query_tasks_for_policy.find_by(id: params[:id])
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

  # Load a track from the tracking list checking the data visibility policy,
  # used by the actions reachable from that page (destroy, change date).
  def manageable_track_finder
    @track = Tasks::Track.find_by(id: params[:track_id])
    unless @track
      flash[:danger] = "Tracking non trovato"
      return false
    end

    if @session_user.policy?("only_data_projects_as_member") &&
       !@session_user.projects_as_member_ids.include?(@track.task&.project_id)
      flash[:danger] = "Non hai i permessi per gestire questo tracking"
      return false
    end

    true
  end

  # Keep the tracking list filters/pagination when redirecting back to it.
  # The day filter travels as `filter_date` because `date` is an action payload.
  def tracks_path_with_current_filters
    tasks_tracks_path(
      project_id: params[:project_id],
      task_id: params[:task_id],
      date: params[:filter_date].presence,
      page: params[:page]
    )
  end
end
