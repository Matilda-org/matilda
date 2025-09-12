# frozen_string_literal: true

# CredentialsController.
class CredentialsController < ApplicationController
  before_action :validate_session_user!
  before_action do
    @_navbar = "credentials"
  end

  caches_action :index, cache_path: -> { current_cache_action_path }, layout: false
  def index
    return unless validate_policy!("credentials_index")

    query = Credential.all
    @credentials_preferred = params[:folder_id].present? || params[:without_folder].present? ? [] : query.user_preferred(@session_user_id).order(name: :asc)

    # manage folder
    if params[:folder_id].present?
      query = query.for_folder(params[:folder_id])
      @folder = Folder.find_by_id(params[:folder_id])
      unless @folder
        flash[:danger] = "Cartella non trovata"
        redirect_to projects_path
        return
      end
    end

    # manage not folder
    query = query.without_folder if params[:without_folder].present?

    query = query.where("LOWER(name) LIKE :search", search: "%#{params[:search].downcase}%") unless params[:search].blank?
    query = query.order(name: :asc)
    @credentials = paginate_query(query.where.not(id: @credentials_preferred.pluck(:id)))
  end

  caches_action :actions, cache_path: -> { current_cache_action_path }, layout: false
  def actions
    @type = params[:type]
    @credential = params[:id].present? ? Credential.find(params[:id]) : Credential.new

    # log credential show
    if @type == "show" && @credential.persisted?
      @session_user.log_credential(@credential.id)
    end

    return render "credentials/actions/create" if @type == "create"
    return render "credentials/actions/edit" if @type == "edit"
    return render "credentials/actions/destroy" if @type == "destroy"
    return render "credentials/actions/show" if @type == "show"

    render partial: "shared/action-error"
  end

  def set_phrase_action
    return unless validate_policy!("credentials_set_phrase")
    Setting.set("credentials_phrase", params.permit(:phrase)[:phrase], "string")

    render partial: "shared/action-feedback", locals: {
      title: "Password di criptazione",
      turbo_frame: "_top",
      feedback_args: {
        title: "Password di criptazione impostata",
        subtitle: "La password di criptazione è stata impostata. Condividila con i tuoi colleghi per permettergli di utilizzare il modulo credenziali.",
        type: "success"
      }
    }
  end

  def create_action
    return unless validate_policy!("credentials_create")

    @credential = Credential.new(credential_params)
    return render "credentials/actions/create" unless @credential.save

    render partial: "shared/action-feedback", locals: {
      title: "Nuova credenziale",
      turbo_frame: "page-main",
      feedback_args: {
        title: "Credenziale salvata",
        subtitle: "La credenziale è stato creata con successo.",
        render_content: "credentials/shared/card",
        render_content_args: { credential: @credential },
        type: "success"
      }
    }
  end

  def edit_action
    return unless validate_policy!("credentials_edit")
    return unless credential_finder

    return render "projects/actions/edit" unless @credential.update(credential_params)

    render partial: "shared/action-feedback", locals: {
      title: "Modifica credenziale",
      turbo_frame: "page-main",
      feedback_args: {
        title: "Credenziale salvata",
        subtitle: "La credenziale è stato modificata con successo.",
        render_content: "credentials/shared/card",
        render_content_args: { credential: @credential },
        type: "success"
      }
    }
  end

  def destroy_action
    return unless validate_policy!("credentials_destroy")
    return unless credential_finder

    @credential.destroy

    render partial: "shared/action-feedback", locals: {
      title: "Elimina credenziale",
      turbo_frame: "page-main",
      feedback_args: {
        title: "Credenziale eliminata",
        subtitle: "La credenziale è stata rimossa dal sistema.",
        type: "success"
      }
    }
  end

  private

  def credential_params
    params.permit(:name, :secure_username, :secure_password, :secure_content)
  end

  def credential_finder
    @credential = Credential.find_by(id: params[:id])
    unless @credential
      flash[:danger] = "Credenziale non trovata"
      redirect_to credentials_path
      return false
    end

    true
  end
end
