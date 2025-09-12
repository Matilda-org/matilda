# frozen_string_literal: true

# ProceduresController.
class ProceduresController < ApplicationController
  before_action :validate_session_user!
  before_action do
    @_navbar = "procedures"
  end

  caches_action :index, cache_path: -> { current_cache_action_path }, layout: false
  def index
    return unless validate_policy!("procedures_index")

    query = Procedure.all.includes(:project).left_joins(:project)
    @procedures_preferred = query.user_preferred(@session_user_id).order("procedures.resources_type ASC, procedures.name ASC")

    query = query.not_as_model.not_archived if params[:filters] == "not-archived" || params[:filters].blank?
    query = query.not_as_model.archived if params[:filters] == "archived"
    query = query.as_model if params[:filters] == "model"
    query = query.search(params[:search]) unless params[:search].blank?
    query = query.order("procedures.resources_type ASC, procedures.name ASC")

    @procedures = paginate_query(query.where.not(id: @procedures_preferred.pluck(:id)))
  end

  caches_action :show, cache_path: -> { current_cache_action_path }, layout: false
  def show
    return unless validate_policy!("procedures_show")

    nil unless procedure_finder
  end

  caches_action :actions, cache_path: -> { current_cache_action_path }, layout: false
  def actions
    @type = params[:type]
    @procedure = params[:id].present? ? Procedure.find(params[:id]) : Procedure.new

    return render "procedures/actions/create" if @type == "create"
    return render "procedures/actions/edit" if @type == "edit"
    return render "procedures/actions/archive" if @type == "archive"
    return render "procedures/actions/unarchive" if @type == "unarchive"
    return render "procedures/actions/clone" if @type == "clone"
    return render "procedures/actions/destroy" if @type == "destroy"
    return render "procedures/actions/add_status" if @type == "add-status"
    return render "procedures/actions/edit_status" if @type == "edit-status" && procedures_status_finder
    return render "procedures/actions/remove_status" if @type == "remove-status" && procedures_status_finder
    return render "procedures/actions/show_status_automations" if @type == "show-status-automations" && procedures_status_finder
    return render "procedures/actions/add_item" if @type == "add-item"
    return render "procedures/actions/add_item_existing" if @type == "add-item-existing"
    return render "procedures/actions/edit_item" if @type == "edit-item" && procedures_item_finder
    return render "procedures/actions/remove_item" if @type == "remove-item" && procedures_item_finder
    return render "procedures/actions/search" if @type == "search"

    render partial: "shared/action-error"
  end

  def toggle_show_archived_projects_action
    return unless validate_policy!("procedures_edit")
    return unless procedure_finder

    @procedure.update(show_archived_projects: !@procedure.show_archived_projects)

    redirect_to procedures_show_path(@procedure)
  end

  def create_action
    return unless validate_policy!("procedures_create")

    @procedure = Procedure.new(procedure_params)
    return render "procedures/actions/create" unless @procedure.save

    render partial: "shared/action-feedback", locals: {
      title: "Nuova board",
      turbo_frame: "_top",
      feedback_args: {
        title: "Board creata",
        subtitle: "La board #{@procedure.name} è stata creata con successo.",
        render_content: "procedures/shared/card",
        render_content_args: { procedure: @procedure },
        type: "success"
      }
    }
  end

  def edit_action
    return unless validate_policy!("procedures_edit")
    return unless procedure_finder

    return render "procedures/actions/edit" unless @procedure.update(procedure_params)

    render partial: "shared/action-feedback", locals: {
      title: "Modifica board",
      turbo_frame: params[:turbo_frame_key] || "page-header",
      feedback_args: {
        title: "Board aggiornata",
        subtitle: "La board #{@procedure.name} è stata aggiornata con successo.",
        render_content: "procedures/shared/card",
        render_content_args: { procedure: @procedure },
        type: "success"
      }
    }
  end

  def archive_action
    return unless validate_policy!("procedures_archive")
    return unless procedure_finder

    return render "procedures/actions/archive" unless @procedure.update(archived: true)

    render partial: "shared/action-feedback", locals: {
      title: "Archivia board",
      turbo_frame: "page-header",
      feedback_args: {
        title: "Board archiviata",
        subtitle: "La board #{@procedure.name} è stata archiviata con successo.",
        render_content: "procedures/shared/card",
        render_content_args: { procedure: @procedure },
        type: "success"
      }
    }
  end

  def unarchive_action
    return unless validate_policy!("procedures_unarchive")
    return unless procedure_finder

    return render "procedures/actions/unarchive" unless @procedure.update(archived: false)

    render partial: "shared/action-feedback", locals: {
      title: "Ri-attiva board",
      turbo_frame: "page-header",
      feedback_args: {
        title: "Board ri-attivata",
        subtitle: "La board #{@procedure.name} è stato ri-attivata con successo.",
        render_content: "procedures/shared/card",
        render_content_args: { procedure: @procedure },
        type: "success"
      }
    }
  end

  def clone_action
    return unless validate_policy!("procedures_clone")
    return unless procedure_finder

    new_procedure = Procedure.new
    return render "procedures/actions/clone" unless new_procedure.clone(@procedure)

    render partial: "shared/action-feedback", locals: {
      title: "Clona board",
      turbo_frame: "_top",
      feedback_args: {
        title: "Board clonata",
        subtitle: "La board #{@procedure.name} è stata clonata con successo.",
        render_content: "procedures/shared/card",
        render_content_args: { procedure: new_procedure },
        type: "success"
      }
    }
  end

  def destroy_action
    return unless validate_policy!("procedures_destroy")
    return unless procedure_finder

    @procedure.destroy

    render partial: "shared/action-feedback", locals: {
      title: "Elimina board",
      turbo_frame: "_top",
      feedback_args: {
        title: "Board eliminata",
        subtitle: "La board #{@procedure.name} è stato eliminata.",
        type: "success"
      }
    }
  end

  # STATUSES
  ################################################################################

  def add_status_action
    return unless validate_policy!("procedures_edit")
    return unless procedure_finder

    @status = @procedure.procedures_statuses.new(params.permit(:title, :description).merge(procedure_id: @procedure.id))
    return render "procedures/actions/add_status" unless @status.save

    render partial: "shared/action-feedback", locals: {
      title: "Aggiungi stato",
      turbo_frame: dom_id(@procedure, "kanban"),
      feedback_args: {
        title: "Stato aggiunto",
        subtitle: "Il nuovo stato è ora aggiunto alla board.",
        type: "success"
      }
    }
  end

  def edit_status_action
    return unless validate_policy!("procedures_edit")
    return unless procedure_finder
    return unless procedures_status_finder

    return render "procedures/actions/edit_status" unless @status.update(params.permit(:title, :description))

    render partial: "shared/action-feedback", locals: {
      title: "Modifica stato",
      turbo_frame: dom_id(@status, "kanban-status"),
      feedback_args: {
        title: "Stato modificato",
        subtitle: "Le modifiche allo stato sono state salvate.",
        type: "success"
      }
    }
  end

  def remove_status_action
    return unless validate_policy!("procedures_edit")
    return unless procedure_finder
    return unless procedures_status_finder

    @status.destroy

    render partial: "shared/action-feedback", locals: {
      title: "Rimuovi stato",
      turbo_frame: dom_id(@procedure, "kanban"),
      feedback_args: {
        title: "Stato rimosso",
        subtitle: "Lo stato non è più presente nella board.",
        type: "success"
      }
    }
  end

  def move_status_action
    return unless validate_policy!("procedures_edit")
    return unless procedure_finder
    return unless procedures_status_finder

    @status.move(params.permit(:direction)[:direction])

    render partial: "procedures/kanban", locals: { procedure: @procedure }
  end

  def toggle_status_automation_action
    return unless validate_policy!("procedures_edit")
    return unless procedure_finder
    return unless procedures_status_finder

    if @status.automation?(params[:automation])
      @status.remove_automation(params[:automation])
    else
      @status.add_automation(params[:automation])
    end

    render "procedures/actions/show_status_automations"
  end

  # ITEMS
  ################################################################################

  def add_item_action
    return unless validate_policy!("procedures_edit")
    return unless procedure_finder

    @item = @procedure.procedures_items.new(params.permit(:title, :procedures_status_id, :resource_id))

    update_item_model_data
    return render "procedures/actions/add_item" unless @item.save

    render partial: "shared/action-feedback", locals: {
      title: "Aggiungi #{@procedure.resources_item_string}",
      turbo_frame: params[:turbo_frame_key] || dom_id(@procedure, "kanban"),
      feedback_args: {
        title: "#{@procedure.resources_item_string.capitalize} aggiunto",
        subtitle: "Il nuovo #{@procedure.resources_item_string} è stato aggiunto alla board.",
        type: "success"
      }
    }
  end

  def edit_item_action
    return unless validate_policy!("procedures_edit")
    return unless procedure_finder
    return unless procedures_item_finder

    update_item_model_data
    return render "procedures/actions/edit_status" unless @item.update(params.permit(:title, :resource_id))

    render partial: "shared/action-feedback", locals: {
      title: "Modifica #{@procedure.resources_item_string}",
      turbo_frame: params[:turbo_frame_key] || dom_id(@procedure, "kanban"),
      feedback_args: {
        title: "#{@procedure.resources_item_string.capitalize} modificato",
        subtitle: "Le modifiche sono state salvate.",
        type: "success"
      }
    }
  end

  def remove_item_action
    return unless validate_policy!("procedures_edit")
    return unless procedure_finder
    return unless procedures_item_finder

    @item.destroy

    render partial: "shared/action-feedback", locals: {
      title: "Rimuovi #{@procedure.resources_item_string}",
      turbo_frame: params[:turbo_frame_key] || "_top",
      feedback_args: {
        title: "#{@procedure.resources_item_string.capitalize} rimosso",
        subtitle: "La rimozione è avvenuta con successo.",
        type: "success"
      }
    }
  end

  def move_item_action
    return unless validate_policy!("procedures_edit")
    return unless procedure_finder
    return unless procedures_item_finder

    p = params.permit(:procedures_status_id, :order)
    @item.move(p[:procedures_status_id], p[:order])

    render partial: "procedures/kanban-item", locals: { item: @item, turbo_frame_status_key: dom_id(@item.procedures_status, "kanban-status") }
  end

  private

  def procedure_params
    params.permit(:name, :description, :resources_type, :model, :project_primary)
  end

  def procedure_finder
    @procedure = Procedure.find_by(id: params[:id])
    unless @procedure
      flash[:danger] = "Board non trovata"
      redirect_to procedures_path
      return false
    end

    true
  end

  def procedures_status_finder
    @status = @procedure.procedures_statuses.find_by(id: params[:status_id])
    unless @status
      flash[:danger] = "Partecipante non trovato"
      redirect_to procedures_show_path(@procedure)
      return false
    end

    true
  end

  def procedures_item_finder
    @item = @procedure.procedures_items.find_by(id: params[:item_id])
    unless @item
      flash[:danger] = "Elemento non trovato"
      redirect_to procedures_show_path(@procedure)
      return false
    end

    true
  end

  def update_item_model_data
    return unless @procedure.model && @procedure.resources_type_tasks?

    @item.update(model_data: params.to_unsafe_hash.reject { |k| %w[authenticity_token controller action procedures_status_id turbo_frame_key resource_id item_id id].include?(k) })
  end
end
