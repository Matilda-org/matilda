# frozen_string_literal: true

# Communications API: read a single communication and manage its notes,
# so external tools can log what happened on a contact of a campaign.
class Api::V1::CommunicationsController < Api::V1::BaseController
  # GET /api/v1/communications/:id
  def show
    return unless require_policy!("crm")

    communication = Communication.find(params[:id])
    render json: communication.as_json(include: [ :contact, :campaign, :communications_follow_ups ])
  end

  # POST /api/v1/communications/:id/send
  def mark_sent
    return unless require_policy!("crm")

    communication = Communication.find(params[:id])
    date = params[:sent_date].presence || Date.today
    return render_record_errors(communication) unless communication.mark_sent(date)

    render json: communication.as_json
  end

  # POST /api/v1/communications/:id/close
  def mark_closed
    return unless require_policy!("crm")

    communication = Communication.find(params[:id])
    date = params[:closed_date].presence || Date.today
    return render_record_errors(communication) unless communication.mark_closed(params[:status], date)

    render json: communication.as_json
  end

  # POST /api/v1/communications/:id/follow_up
  def follow_up
    return unless require_policy!("crm")

    communication = Communication.find(params[:id])
    follow_up = communication.register_follow_up(params[:date], @current_user)
    return render_record_errors(communication) unless follow_up

    render json: follow_up.as_json, status: :created
  end

  # DELETE /api/v1/communications/:id/follow_ups/:follow_up_id
  def destroy_follow_up
    return unless require_policy!("crm")

    communication = Communication.find(params[:id])
    communication.communications_follow_ups.find(params[:follow_up_id]).destroy

    head :no_content
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
