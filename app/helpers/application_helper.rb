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

  def track_time(seconds)
    seconds_diff = seconds
    hours = seconds_diff / 3600
    seconds_diff -= hours * 3600
    minutes = seconds_diff / 60

    "#{hours.to_s.rjust(2, '0')}h #{minutes.to_s.rjust(2, '0')}m"
  end

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
end
