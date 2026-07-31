# frozen_string_literal: true

# Procedures API: read access to procedures with statuses and items.
class Api::V1::ProceduresController < Api::V1::BaseController
  # GET /api/v1/procedures
  def index
    return unless require_policy!("procedures_index")

    procedures = query_procedures_for_policy.order(name: :asc)
    procedures = procedures.not_archived unless params[:archived].present?
    procedures = procedures.archived if params[:archived].present?
    render_paginated(procedures)
  end

  # GET /api/v1/procedures/:id
  def show
    return unless require_policy!("procedures_show")

    procedure = query_procedures_for_policy.find(params[:id])
    render json: procedure.as_json(include: [ :procedures_statuses, :procedures_items, :projects_items, :tasks_items, :project ])
  end
end
