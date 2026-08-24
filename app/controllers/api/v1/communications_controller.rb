# frozen_string_literal: true

# Communications API: read a single communication and manage its notes,
# so external tools can log what happened on a contact of a campaign.
class Api::V1::CommunicationsController < Api::V1::BaseController
  # GET /api/v1/communications/:id
  def show
    return unless require_policy!("crm")

    communication = Communication.find(params[:id])
    render json: communication.as_json(include: [ :contact, :campaign ])
  end

  # GET /api/v1/communications/:id/logs
  def logs
    return unless require_policy!("crm")

    communication = Communication.find(params[:id])
    render_paginated(communication.communications_logs.recent_first, with_content: true)
  end

  # POST /api/v1/communications/:id/logs
  def create_log
    return unless require_policy!("crm")

    communication = Communication.find(params[:id])
    log = communication.communications_logs.new(content: params[:content], user: @current_user)
    return render_record_errors(log) unless log.save

    render json: log.as_json(with_content: true), status: :created
  end

  # DELETE /api/v1/communications/:id/logs/:log_id
  def destroy_log
    return unless require_policy!("crm")

    communication = Communication.find(params[:id])
    log = communication.communications_logs.find(params[:log_id])
    log.destroy

    head :no_content
  end
end
