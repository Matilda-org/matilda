# frozen_string_literal: true

# FoldersController.
class FoldersController < ApplicationController
  before_action :validate_session_user!

  caches_action :show, cache_path: -> { current_cache_action_path }, layout: false
  def show
    return unless folder_finder

    @projects = @folder.projects.not_archived.order(name: :asc)
    @credentials = @folder.credentials.order(name: :asc)
  end

  caches_action :actions, cache_path: -> { current_cache_action_path }, layout: false
  def actions
    @type = params[:type]
    @folder = params[:id].present? ? Folder.find(params[:id]) : Folder.new
    @item = params[:item_id].present? ? Folders::Item.find(params[:item_id]) : Folders::Item.new(params.permit(:resource_type, :resource_id))

    return render "folders/actions/create" if @type == "create"
    return render "folders/actions/manage-resource" if @type == "manage-resource"
    return render "folders/actions/edit" if @type == "edit" && folder_finder
    return render "folders/actions/destroy" if @type == "destroy" && folder_finder

    render partial: "shared/action-error"
  end

  def create_action
    return unless validate_policy!("folders_create")

    @folder = Folder.new(folder_params)
    return render "folders/actions/create" unless @folder.save

    create_procedure_item(@folder.id)
    render partial: "shared/action-feedback", locals: {
      title: "Nuova cartella",
      turbo_frame: params[:turbo_frame_key] || "_top",
      feedback_args: {
        title: "Cartella creata",
        subtitle: "La cartella #{@folder.name} è stata creata con successo.",
        type: "success"
      }
    }
  end

  def edit_action
    return unless validate_policy!("folders_edit")
    return unless folder_finder

    return render "folders/actions/edit" unless @folder.update(folder_params)

    render partial: "shared/action-feedback", locals: {
      title: "Modifica cartella",
      turbo_frame: params[:turbo_frame_key] || "_top",
      feedback_args: {
        title: "Cartella aggiornata",
        subtitle: "La cartella #{@folder.name} è stata aggiornata con successo.",
        type: "success"
      }
    }
  end

  def destroy_action
    return unless validate_policy!("folders_destroy")
    return unless folder_finder

    @folder.destroy

    render partial: "shared/action-feedback", locals: {
      title: "Elimina cartella",
      turbo_frame: "_top",
      feedback_args: {
        title: "Cartella eliminata",
        subtitle: "La cartela #{@folder.name} è stata eliminata.",
        type: "success"
      }
    }
  end

  def manage_resource_action
    return unless validate_policy!("folders_manage_resources")

    # destroy old folder item
    old_item = Folders::Item.find_by(params.permit(:resource_type, :resource_id))
    old_item&.destroy

    # create new folder item
    unless params[:folder_id].blank?
      @item = Folders::Item.new(params.permit(:resource_type, :resource_id, :folder_id))
      return render "folders/actions/manage-resource" unless @item.save
    end

    render partial: "shared/action-feedback", locals: {
      title: "Gestisci cartella",
      turbo_frame: params[:turbo_frame_key] || "_top",
      feedback_args: {
        title: "Cartella aggiornata",
        subtitle: "L'elemento è stato aggiornato correttamente.",
        type: "success"
      }
    }
  end

  private

  def folder_params
    params.permit(:name)
  end

  def folder_finder
    @folder = Folder.find_by(id: params[:id])
    unless @folder
      flash[:danger] = "Cartella non trovato"
      redirect_to root_path
      return false
    end

    true
  end
end
