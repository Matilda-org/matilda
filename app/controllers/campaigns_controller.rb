# frozen_string_literal: true

# CampaignsController: campaigns and their communications kanban.
class CampaignsController < ApplicationController
  before_action :validate_session_user!
  before_action do
    @_navbar = "campaigns"
  end

  caches_action :index, cache_path: -> { current_cache_action_path }, layout: false
  def index
    return unless validate_policy!("crm")

    query = Campaign.all
    query = query.not_archived if params[:filters] == "not-archived" || params[:filters].blank?
    query = query.archived if params[:filters] == "archived"
    query = query.search(params[:search]) unless params[:search].blank?
    if params[:sort] == "name_desc"
      query = query.order(name: :desc)
    elsif params[:sort] == "created_desc"
      query = query.order(created_at: :desc)
    else
      query = query.order(name: :asc)
    end

    @campaigns = paginate_query(query)
  end

  caches_action :show, cache_path: -> { current_cache_action_path }, layout: false
  def show
    return unless validate_policy!("crm")

    nil unless campaign_finder
  end

  caches_action :actions, cache_path: -> { current_cache_action_path }, layout: false
  def actions
    @type = params[:type]
    @campaign = params[:id].present? ? Campaign.find(params[:id]) : Campaign.new

    return render "campaigns/actions/create" if @type == "create"
    return render "campaigns/actions/edit" if @type == "edit"
    return render "campaigns/actions/archive" if @type == "archive"
    return render "campaigns/actions/unarchive" if @type == "unarchive"
    return render "campaigns/actions/destroy" if @type == "destroy"

    return render "campaigns/actions/add_communication" if @type == "add-communication"
    if @type == "send-communication"
      return unless communication_finder
      return render "campaigns/actions/send_communication"
    end
    if @type == "close-communication"
      return unless communication_finder
      return render "campaigns/actions/close_communication"
    end
    if @type == "show-communication"
      return unless communication_finder
      return render "campaigns/actions/show_communication"
    end
    if @type == "remove-communication"
      return unless communication_finder
      return render "campaigns/actions/remove_communication"
    end

    render partial: "shared/action-error"
  end

  def create_action
    return unless validate_policy!("crm")

    @campaign = Campaign.new(campaign_params)
    return render "campaigns/actions/create" unless @campaign.save

    render partial: "shared/action-feedback", locals: {
      title: "Nuova campagna",
      turbo_frame: params[:turbo_frame_key] || "_top",
      feedback_args: {
        title: "Campagna creata",
        subtitle: "La campagna #{@campaign.name} è stata creata con successo.",
        render_content: "campaigns/shared/card",
        render_content_args: { campaign: @campaign },
        type: "success"
      }
    }
  end

  def edit_action
    return unless validate_policy!("crm")
    return unless campaign_finder

    return render "campaigns/actions/edit" unless @campaign.update(campaign_params)

    render partial: "shared/action-feedback", locals: {
      title: "Modifica campagna",
      turbo_frame: params[:turbo_frame_key] || "_top",
      feedback_args: {
        title: "Campagna aggiornata",
        subtitle: "La campagna #{@campaign.name} è stata aggiornata con successo.",
        type: "success"
      }
    }
  end

  def archive_action
    return unless validate_policy!("crm")
    return unless campaign_finder

    @campaign.update(archived: true)

    render partial: "shared/action-feedback", locals: {
      title: "Archivia campagna",
      turbo_frame: params[:turbo_frame_key] || "_top",
      feedback_args: {
        title: "Campagna archiviata",
        subtitle: "La campagna #{@campaign.name} è stata archiviata con successo.",
        type: "success"
      }
    }
  end

  def unarchive_action
    return unless validate_policy!("crm")
    return unless campaign_finder

    @campaign.update(archived: false)

    render partial: "shared/action-feedback", locals: {
      title: "Ri-attiva campagna",
      turbo_frame: params[:turbo_frame_key] || "_top",
      feedback_args: {
        title: "Campagna ri-attivata",
        subtitle: "La campagna #{@campaign.name} è stata ri-attivata con successo.",
        type: "success"
      }
    }
  end

  def destroy_action
    return unless validate_policy!("crm")
    return unless campaign_finder

    @campaign.destroy

    render partial: "shared/action-feedback", locals: {
      title: "Elimina campagna",
      turbo_frame: params[:turbo_frame_key] || "_top",
      feedback_args: {
        title: "Campagna eliminata",
        subtitle: "La campagna #{@campaign.name} è stata eliminata.",
        type: "success"
      }
    }
  end

  # COMMUNICATIONS
  ################################################################################

  def add_communication_action
    return unless validate_policy!("crm")
    return unless campaign_finder

    @communication = @campaign.communications.new(contact_id: params[:contact_id])
    return render "campaigns/actions/add_communication" unless @communication.save

    render_communication_feedback("Aggiungi comunicazione", "Comunicazione creata", "La comunicazione con #{@communication.contact.name} è pronta per l'invio.")
  end

  def send_communication_action
    return unless validate_policy!("crm")
    return unless campaign_finder
    return unless communication_finder

    return render "campaigns/actions/send_communication" unless @communication.mark_sent(params[:sent_date])

    render_communication_feedback("Conferma invio", "Comunicazione inviata", "L'invio a #{@communication.contact.name} è stato registrato in data #{@communication.sent_date.strftime('%d/%m/%Y')}.")
  end

  def close_communication_action
    return unless validate_policy!("crm")
    return unless campaign_finder
    return unless communication_finder

    return render "campaigns/actions/close_communication" unless @communication.mark_closed(params[:final_status], params[:closed_date])

    render_communication_feedback("Registra esito", "Esito registrato", "La comunicazione con #{@communication.contact.name} è stata chiusa come #{@communication.status_string.upcase}.")
  end

  def follow_up_communication_action
    return unless validate_policy!("crm")
    return unless campaign_finder
    return unless communication_finder

    unless @communication.register_follow_up
      flash[:danger] = "I follow-up si registrano solo su comunicazioni inviate"
      redirect_to campaigns_show_path(@campaign)
      return
    end

    render_communication_feedback("Registra follow-up", "Follow-up registrato", "Follow-up ##{@communication.follow_ups_count} con #{@communication.contact.name} registrato.")
  end

  def remove_communication_action
    return unless validate_policy!("crm")
    return unless campaign_finder
    return unless communication_finder

    @communication.destroy

    render_communication_feedback("Elimina comunicazione", "Comunicazione eliminata", "La comunicazione con #{@communication.contact.name} è stata eliminata.")
  end

  def add_communication_log_action
    return unless validate_policy!("crm")
    return unless campaign_finder
    return unless communication_finder

    @log = @communication.communications_logs.new(content: params[:content], user_id: @session_user_id)
    return render "campaigns/actions/show_communication" unless @log.save

    render_communication_feedback("Aggiungi nota", "Nota aggiunta", "La nota è stata aggiunta alla comunicazione con #{@communication.contact.name}.")
  end

  def remove_communication_log_action
    return unless validate_policy!("crm")
    return unless campaign_finder
    return unless communication_finder

    log = @communication.communications_logs.find_by(id: params[:log_id])
    log&.destroy

    render_communication_feedback("Rimuovi nota", "Nota rimossa", "La nota è stata rimossa.")
  end

  private

  def campaign_params
    params.permit(:name, :description)
  end

  def campaign_finder
    @campaign = Campaign.find_by(id: params[:id])
    unless @campaign
      flash[:danger] = "Campagna non trovata"
      redirect_to campaigns_path
      return false
    end

    true
  end

  def communication_finder
    @communication = @campaign.communications.find_by(id: params[:communication_id])
    unless @communication
      flash[:danger] = "Comunicazione non trovata"
      redirect_to campaigns_show_path(@campaign)
      return false
    end

    true
  end

  def render_communication_feedback(title, feedback_title, subtitle)
    render partial: "shared/action-feedback", locals: {
      title: title,
      turbo_frame: "campaign-kanban",
      feedback_args: {
        title: feedback_title,
        subtitle: subtitle,
        type: "success"
      }
    }
  end
end
