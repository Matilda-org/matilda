# frozen_string_literal: true

# Campaigns API: campaigns read access and communication creation, so external
# tools can enqueue contacts into a campaign.
class Api::V1::CampaignsController < Api::V1::BaseController
  # GET /api/v1/campaigns
  def index
    return unless require_policy!("crm")

    campaigns = Campaign.order(name: :asc)
    campaigns = campaigns.not_archived unless params[:archived].present?
    campaigns = campaigns.archived if params[:archived].present?
    campaigns = campaigns.search(params[:search]) if params[:search].present?
    render_paginated(campaigns)
  end

  # GET /api/v1/campaigns/:id
  def show
    return unless require_policy!("crm")

    campaign = Campaign.find(params[:id])
    render json: campaign.as_json(include: { communications: { include: :contact } })
  end

  # POST /api/v1/campaigns/:id/communications
  def create_communication
    return unless require_policy!("crm")

    campaign = Campaign.find(params[:id])
    communication = campaign.communications.new(contact_id: params[:contact_id])
    return render_record_errors(communication) unless communication.save

    render json: communication.as_json, status: :created
  end
end
