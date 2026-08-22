# frozen_string_literal: true

# ContactsController.
class ContactsController < ApplicationController
  before_action :validate_session_user!
  before_action do
    @_navbar = "contacts"
  end

  caches_action :index, cache_path: -> { current_cache_action_path }, layout: false
  def index
    return unless validate_policy!("crm")

    query = Contact.all
    query = query.not_archived if params[:filters] == "not-archived" || params[:filters].blank?
    query = query.archived if params[:filters] == "archived"
    query = query.search(params[:search]) unless params[:search].blank?
    if params[:sort] == "name_desc"
      query = query.order(name: :desc)
    else
      query = query.order(name: :asc)
    end

    @contacts = paginate_query(query)
  end

  caches_action :show, cache_path: -> { current_cache_action_path }, layout: false
  def show
    return unless validate_policy!("crm")

    nil unless contact_finder
  end

  caches_action :actions, cache_path: -> { current_cache_action_path }, layout: false
  def actions
    @type = params[:type]
    @contact = params[:id].present? ? Contact.find(params[:id]) : Contact.new

    return render "contacts/actions/create" if @type == "create"
    return render "contacts/actions/edit" if @type == "edit"
    return render "contacts/actions/archive" if @type == "archive"
    return render "contacts/actions/unarchive" if @type == "unarchive"
    return render "contacts/actions/destroy" if @type == "destroy"

    return render "contacts/actions/link_project" if @type == "link-project"
    if @type == "unlink-project"
      return unless contacts_project_finder
      return render "contacts/actions/unlink_project"
    end

    render partial: "shared/action-error"
  end

  def create_action
    return unless validate_policy!("crm")

    @contact = Contact.new(contact_params)
    return render "contacts/actions/create" unless @contact.save

    render partial: "shared/action-feedback", locals: {
      title: "Nuovo contatto",
      turbo_frame: params[:turbo_frame_key] || "_top",
      feedback_args: {
        title: "Contatto creato",
        subtitle: "Il contatto #{@contact.name} è stato creato con successo.",
        render_content: "contacts/shared/card",
        render_content_args: { contact: @contact },
        type: "success"
      }
    }
  end

  def edit_action
    return unless validate_policy!("crm")
    return unless contact_finder

    return render "contacts/actions/edit" unless @contact.update(contact_params)

    render partial: "shared/action-feedback", locals: {
      title: "Modifica contatto",
      turbo_frame: params[:turbo_frame_key] || "_top",
      feedback_args: {
        title: "Contatto aggiornato",
        subtitle: "Il contatto #{@contact.name} è stato aggiornato con successo.",
        render_content: "contacts/shared/card",
        render_content_args: { contact: @contact },
        type: "success"
      }
    }
  end

  def archive_action
    return unless validate_policy!("crm")
    return unless contact_finder

    @contact.update(archived: true)

    render partial: "shared/action-feedback", locals: {
      title: "Archivia contatto",
      turbo_frame: params[:turbo_frame_key] || "_top",
      feedback_args: {
        title: "Contatto archiviato",
        subtitle: "Il contatto #{@contact.name} è stato archiviato con successo.",
        type: "success"
      }
    }
  end

  def unarchive_action
    return unless validate_policy!("crm")
    return unless contact_finder

    @contact.update(archived: false)

    render partial: "shared/action-feedback", locals: {
      title: "Ri-attiva contatto",
      turbo_frame: params[:turbo_frame_key] || "_top",
      feedback_args: {
        title: "Contatto ri-attivato",
        subtitle: "Il contatto #{@contact.name} è stato ri-attivato con successo.",
        type: "success"
      }
    }
  end

  def destroy_action
    return unless validate_policy!("crm")
    return unless contact_finder

    @contact.destroy

    render partial: "shared/action-feedback", locals: {
      title: "Elimina contatto",
      turbo_frame: params[:turbo_frame_key] || "_top",
      feedback_args: {
        title: "Contatto eliminato",
        subtitle: "Il contatto #{@contact.name} è stato eliminato.",
        type: "success"
      }
    }
  end

  # PROJECTS
  ################################################################################

  def link_project_action
    return unless validate_policy!("crm")
    return unless contact_finder

    @project = Project.where(contact_id: nil).find_by(id: params[:project_id])
    unless @project&.update(contact: @contact)
      flash[:danger] = "Progetto non trovato o già collegato"
      redirect_to contacts_show_path(@contact)
      return
    end

    render partial: "shared/action-feedback", locals: {
      title: "Collega progetto",
      turbo_frame: "module-projects",
      feedback_args: {
        title: "Progetto collegato",
        subtitle: "Il progetto #{@project.name} è ora collegato a #{@contact.name}",
        type: "success"
      }
    }
  end

  def unlink_project_action
    return unless validate_policy!("crm")
    return unless contact_finder
    return unless contacts_project_finder

    @project.update(contact: nil)

    render partial: "shared/action-feedback", locals: {
      title: "Scollega progetto",
      turbo_frame: "module-projects",
      feedback_args: {
        title: "Progetto scollegato",
        subtitle: "Il progetto #{@project.name} non è più collegato a #{@contact.name}",
        type: "success"
      }
    }
  end

  private

  def contact_params
    params.permit(:name, :vat_number, :email, :phone, :website, :address, :description)
  end

  def contact_finder
    @contact = Contact.find_by(id: params[:id])
    unless @contact
      flash[:danger] = "Contatto non trovato"
      redirect_to contacts_path
      return false
    end

    true
  end

  def contacts_project_finder
    @project = @contact.projects.find_by(id: params[:project_id])
    unless @project
      flash[:danger] = "Progetto non trovato"
      redirect_to contacts_show_path(@contact)
      return false
    end

    true
  end
end
