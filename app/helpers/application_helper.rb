module ApplicationHelper
  def nav_icon(key, classes = "")
    return raw "<i class=\"bi bi-people-fill #{classes}\"></i>" if key == "users"
    return raw "<i class=\"bi bi-file-earmark-text-fill #{classes}\"></i>" if key == "projects"
    return raw "<i class=\"bi bi-sticky-fill #{classes}\"></i>" if key == "tasks"
    return raw "<i class=\"bi bi-kanban-fill #{classes}\"></i>" if key == "procedures"
    return raw "<i class=\"bi bi-shield-fill #{classes}\"></i>" if key == "credentials"
    return raw "<i class=\"bi bi-house-fill #{classes}\"></i>" if key == "dashboard"
    return raw "<i class=\"bi bi-collection-play-fill #{classes}\"></i>" if key == "presentations"
    return raw "<i class=\"bi bi-tools #{classes}\"></i>" if key == "tools"
    return raw "<i class=\"bi bi-gear-fill #{classes}\"></i>" if key == "settings"
    return raw "<i class=\"bi bi-newspaper #{classes}\"></i>" if key == "posts"

    ""
  end

  def nav_title(key)
    return @_nav_title if @_nav_title

    return "Bacheca - Matilda" if key == "posts"
    return "Utenti - Matilda" if key == "users"
    return "Progetti - Matilda" if key == "projects"
    return "Task - Matilda" if key == "tasks"
    return "Processi - Matilda" if key == "procedures"
    return "Credenziali - Matilda" if key == "credentials"
    return "Dashboard - Matilda" if key == "dashboard"
    return "Impostazioni - Matilda" if key == "settings"
    return "Tools - Matilda" if key == "tools"
    return "Presentazioni - Matilda" if key == "presentations"

    "Matilda"
  end

  # Convert tracked time in seconds to "HHh MMm" format
  def track_time(seconds)
    seconds_diff = seconds
    hours = seconds_diff / 3600
    seconds_diff -= hours * 3600
    minutes = seconds_diff / 60

    "#{hours.to_s.rjust(2, '0')}h #{minutes.to_s.rjust(2, '0')}m"
  end

  # Calculate gradient background color for current time
  def background_calculator
    color_start = "#dfe6f3"
    color_end = "#bccce6"
    current_time = Time.now
    start_time = Time.parse("00:00")
    end_time = Time.parse("23:59")

    # Calculate the percentage of the day passed
    percentage = ((current_time - start_time) / (end_time - start_time)) * 100

    "linear-gradient(180deg, #{color_end} #{percentage}%, #{color_start} 100%)"
  end

  # Get the list of users for selects
  def users_for_select
    User.all.order(surname: :asc, name: :asc).map { |u| u.id == @session_user_id ? [ "[ME] #{u.complete_name}", u.id ] : [ u.complete_name, u.id ] }.sort_by! { |u| u[1] == @session_user_id ? 0 : 1 }
  end

  # Tasks helpers
  ###############################################################################

  def tasks_time_estimate_color(tasks)
    total_estimate_time = tasks.map(&:time_estimate).sum
    if total_estimate_time >= 60 * 60 * 7
      "danger"
    elsif total_estimate_time >= 60 * 60 * 5
      "warning"
    elsif total_estimate_time > 0
      "info"
    else
      "success"
    end
  end

  def task_google_calendar_url(task)
    # Parametri per Google Calendar
    title = CGI.escape(task.project ? "#{task.title} | #{task.project.name}" : task.title)
    details = CGI.escape(task.description || "Task creato in Matilda")

    # Se il task ha una deadline, usa quella alle 9:00, altrimenti usa oggi alle 9:00
    if task.deadline
      start_time = task.deadline.beginning_of_day + 9.hours
      end_time = start_time + 1.hour
    else
      start_time = Time.current.beginning_of_day + 9.hours
      end_time = start_time + 1.hour
    end

    # Formato per Google Calendar: YYYYMMDDTHHMMSSZ
    start_formatted = start_time.utc.strftime("%Y%m%dT%H%M%SZ")
    end_formatted = end_time.utc.strftime("%Y%m%dT%H%M%SZ")
    dates = "#{start_formatted}/#{end_formatted}"

    "https://calendar.google.com/calendar/render?action=TEMPLATE&text=#{title}&details=#{details}&dates=#{dates}"
  end

  def task_outlook_calendar_url(task)
    # Parametri per Outlook Calendar
    subject = CGI.escape(task.project ? "#{task.title} | #{task.project.name}" : task.title)
    body = CGI.escape(task.description || "Task creato in Matilda")

    # Se il task ha una deadline, usa quella alle 9:00, altrimenti usa oggi alle 9:00
    if task.deadline
      start_time = task.deadline.beginning_of_day + 9.hours
      end_time = start_time + 1.hour
    else
      start_time = Time.current.beginning_of_day + 9.hours
      end_time = start_time + 1.hour
    end

    # Formato ISO 8601 per Outlook
    start_formatted = start_time.iso8601
    end_formatted = end_time.iso8601

    "https://outlook.live.com/calendar/0/deeplink/compose?subject=#{subject}&body=#{body}&startdt=#{start_formatted}&enddt=#{end_formatted}"
  end
end
