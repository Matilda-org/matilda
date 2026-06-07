class ProjectRiskReport
  STALE_AFTER = 14.days

  def initialize(projects)
    @projects = projects
  end

  def items(limit: 8)
    @projects.not_archived.includes(:tasks, :projects_events, :projects_attachments).filter_map do |project|
      project_item(project)
    end.sort_by { |item| -item[:score] }.first(limit)
  end

  private

  def project_item(project)
    tasks = project.tasks.reject(&:completed?)
    signals = []

    expired_tasks_count = tasks.count { |task| task.deadline && task.deadline < Date.today }
    signals << signal(:danger, "#{expired_tasks_count} task scaduti") if expired_tasks_count.positive?

    unassigned_tasks_count = tasks.count { |task| task.user_id.blank? }
    signals << signal(:warning, "#{unassigned_tasks_count} task senza owner") if unassigned_tasks_count.positive?

    if project.budget_management && project.cached_percentage_budget_used >= 90
      signals << signal(project.cached_percentage_budget_used >= 100 ? :danger : :warning, "Budget tempo al #{project.cached_percentage_budget_used}%")
    end

    last_activity_at = last_activity_at(project)
    if last_activity_at && last_activity_at < STALE_AFTER.ago
      signals << signal(:secondary, "Fermo da #{distance_in_days(last_activity_at)} giorni")
    end

    if tasks.empty? && project.projects_attachments.empty? && project.projects_events.empty?
      signals << signal(:info, "Nessuna attivita operativa")
    end

    return nil if signals.empty?

    {
      project: project,
      score: score(signals),
      signals: signals,
      last_activity_at: last_activity_at
    }
  end

  def signal(level, label)
    { level: level, label: label }
  end

  def score(signals)
    signals.sum do |signal|
      case signal[:level]
      when :danger then 30
      when :warning then 20
      when :secondary then 10
      else 5
      end
    end
  end

  def last_activity_at(project)
    [
      project.updated_at,
      project.tasks.map(&:updated_at).max,
      project.projects_events.map(&:updated_at).max,
      project.projects_attachments.map(&:updated_at).max
    ].compact.max
  end

  def distance_in_days(time)
    ((Time.current - time) / 1.day).floor
  end
end
