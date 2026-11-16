# frozen_string_literal: true

module SearchHelper
  # Marks the searched text inside a result label (escaped, case-insensitive)
  def search_highlight(text, query)
    return "" if text.blank?

    highlight(text.to_s, query, highlighter: '<mark class="c-global-search__match">\1</mark>')
  end

  # Short deadline label for task results: relative when close, a date otherwise
  def search_deadline(task)
    return nil unless task.deadline

    days = (task.deadline - Date.today).to_i
    label = if days.zero?
      "Oggi"
    elsif days == 1
      "Domani"
    elsif days == -1
      "Ieri"
    else
      l(task.deadline, format: "%d %b")
    end

    { label: label, overdue: days.negative? && !task.completed }
  end
end
