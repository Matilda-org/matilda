# frozen_string_literal: true

# Shared bits of the index bulk actions (selection mode of shared/page-index).
# Each controller scopes the records and checks the policies like its
# single-record actions do: ids the user cannot see are simply ignored.
module BulkActions
  extend ActiveSupport::Concern

  private

  def bulk_ids
    Array(params[:ids]).map(&:to_i).uniq
  end

  # Updates only the records not already in the target state and returns them,
  # so the undo reverts exactly what changed
  def bulk_set_archived(records, archived, attributes = {})
    records.where(archived: !archived).select { |record| record.update(attributes.merge(archived: archived)) }
  end

  def render_bulk_feedback(title:, subtitle: nil, undo_href: nil, success: true)
    render partial: "shared/action-feedback", locals: {
      title: "Azione sui selezionati",
      # Closing the feedback reloads the index cards
      turbo_frame: "page-index",
      feedback_args: {
        title: title,
        subtitle: subtitle,
        type: success ? "success" : "light",
        undo: undo_href && { label: "Annulla", href: undo_href }
      }
    }
  end

  # The undo of an undo would be a redo: offer it once, on the original action
  def bulk_undo_allowed?(policy)
    params[:undo].blank? && @session_user.policy?(policy)
  end
end
