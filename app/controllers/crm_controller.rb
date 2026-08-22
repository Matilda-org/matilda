# frozen_string_literal: true

# CrmController: summary dashboard of the CRM section.
class CrmController < ApplicationController
  before_action :validate_session_user!
  before_action do
    @_navbar = "crm"
  end

  caches_action :index, cache_path: -> { current_cache_action_path }, layout: false
  def index
    return unless validate_policy!("crm")

    @campaigns = Campaign.not_archived.order(created_at: :desc)
    @to_send = Communication.to_send.joins(:campaign).where(campaigns: { archived: false }).includes(:contact, :campaign).order(created_at: :asc)
    # oldest sent first: the ones waiting for an outcome the longest
    @waiting = Communication.sent.joins(:campaign).where(campaigns: { archived: false }).includes(:contact, :campaign).order(sent_date: :asc)
  end
end
