module TasksHelper
  def google_calendar_url(task)
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

  def outlook_calendar_url(task)
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
