# frozen_string_literal: true

# ProjectsController.
class ProjectsController < ApplicationController
  before_action :validate_session_user!, except: :show_log
  before_action do
    @_navbar = "projects"
  end

  caches_action :index, cache_path: -> { current_cache_action_path }, layout: false
  def index
    return unless validate_policy!("projects_index")

    query = query_projects_for_policy
    @projects_preferred = params[:folder_id].present? || params[:without_folder].present? ? [] : query.user_preferred(@session_user_id).order(name: :asc)

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

    query = query.not_archived if params[:filters] == "not-archived" || params[:filters].blank?
    query = query.archived if params[:filters] == "archived"
    query = query.search(params[:search]) unless params[:search].blank?
    if params[:sort] == "name_desc"
      query = query.order(name: :desc)
    elsif params[:sort] == "year_asc"
      query = query.order(year: :asc, name: :asc)
    elsif params[:sort] == "year_desc"
      query = query.order(year: :desc, name: :asc)
    else
      query = query.order(name: :asc)
    end

    @projects = paginate_query(query.where.not(id: @projects_preferred.pluck(:id)))
  end

  caches_action :show, cache_path: -> { current_cache_action_path }, layout: false
  def show
    return unless validate_policy!("projects_show")

    nil unless project_finder
  end

  def show_attachment
    @attachment = Projects::Attachment.find(params[:id])
    unless @attachment&.file&.attached?
      send_data "", status: :not_found
      return
    end

    send_data @attachment.file.download, filename: @attachment.file.filename.to_s, type: @attachment.file.content_type.to_s
  end

  caches_action :show_log, cache_path: -> { current_cache_action_path }, layout: false
  def show_log
    @log = Projects::Log.find(params[:id])

    if !@session_user_id && !session["projects_show_log_#{@log.id}"]
      return redirect_to authentication_login_path unless @log.shareable? && params[:share_code] == @log.share_code

      session["projects_show_log_#{@log.id}"] = true
    end

    unless params[:print].blank?
      @_nav_title = @log.title
      @_print_title = @log.title
      render :show_log_print, layout: "application_print"
    end
  end

  caches_action :actions, cache_path: -> { current_cache_action_path }, layout: false
  def actions
    @type = params[:type]
    @project = params[:id].present? ? Project.find(params[:id]) : Project.new

    return render "projects/actions/create" if @type == "create"
    return render "projects/actions/edit" if @type == "edit"
    return render "projects/actions/archive" if @type == "archive"
    return render "projects/actions/unarchive" if @type == "unarchive"
    return render "projects/actions/destroy" if @type == "destroy"
    return render "projects/actions/add_procedure" if @type == "add-procedure"
    return render "projects/actions/add_procedures_item" if @type == "add-procedures-item"

    return render "projects/actions/add_member" if @type == "add-member"
    if @type == "edit-member"
      return unless projects_member_finder
      return render "projects/actions/edit_member"
    end
    if @type == "remove-member"
      return unless projects_member_finder
      return render "projects/actions/remove_member"
    end

    return render "projects/actions/add_log" if @type == "add-log"
    if @type == "show-log"
      return unless projects_log_finder
      return render "projects/actions/show_log"
    end
    if @type == "share-log"
      return unless projects_log_finder
      return render "projects/actions/share_log"
    end
    if @type == "unshare-log"
      return unless projects_log_finder
      return render "projects/actions/unshare_log"
    end
    if @type == "edit-log"
      return unless projects_log_finder
      return render "projects/actions/edit_log"
    end
    if @type == "remove-log"
      return unless projects_log_finder
      return render "projects/actions/remove_log"
    end

    return render "projects/actions/add_attachment" if @type == "add-attachment"
    if @type == "edit-attachment"
      return unless projects_attachment_finder
      return render "projects/actions/edit_attachment"
    end
    if @type == "remove-attachment"
      return unless projects_attachment_finder
      return render "projects/actions/remove_attachment"
    end

    render partial: "shared/action-error"
  end

  def create_action
    return unless validate_policy!("projects_create")

    @project = Project.new(project_params)
    return render "projects/actions/create" unless @project.save

    # create channel on slack
    @project.create_on_slack if params[:_slack]

    # add current user inside project
    @project.projects_members.create(user_id: @session_user_id, role: " - ") if params[:_add_user_to_project_members]

    # add project to folder if folder_id is present
    if params[:folder_id].present?
      folder = Folder.find_by_id(params[:folder_id])
      folder&.folders_items&.create(resource: @project)
    end

    create_procedure_item(@project.id)
    render partial: "shared/action-feedback", locals: {
      title: "Nuovo progetto",
      turbo_frame: params[:turbo_frame_key] || "_top",
      feedback_args: {
        title: "Progetto creato",
        subtitle: "Il progetto #{@project.name} è stato creato con successo. Il suo codice temporaneo è <b>#{@project.code}</b>.",
        render_content: "projects/shared/card",
        render_content_args: { project: @project, interactive: true },
        type: "success"
      }
    }
  end

  def edit_action
    return unless validate_policy!("projects_edit")
    return unless project_finder

    return render "projects/actions/edit" unless @project.update(project_params)

    render partial: "shared/action-feedback", locals: {
      title: "Modifica progetto",
      turbo_frame: params[:turbo_frame_key] || "_top",
      feedback_args: {
        title: "Progetto aggiornato",
        subtitle: "Il progetto #{@project.name} è stato aggiornato con successo.",
        render_content: "projects/shared/card",
        render_content_args: { project: @project },
        type: "success"
      }
    }
  end

  def archive_action
    return unless validate_policy!("projects_archive")
    return unless project_finder

    return render "projects/actions/archive" unless @project.update(params.permit(:archived_reason).merge(archived: true))

    render partial: "shared/action-feedback", locals: {
      title: "Archivia progetto",
      turbo_frame: params[:turbo_frame_key] || "_top",
      feedback_args: {
        title: "Progetto archiviato",
        subtitle: "Il progetto #{@project.name} è stato archiviato con successo.",
        render_content: "projects/shared/card",
        render_content_args: { project: @project },
        type: "success"
      }
    }
  end

  def unarchive_action
    return unless validate_policy!("projects_unarchive")
    return unless project_finder

    return render "projects/actions/unarchive" unless @project.update(archived: false, archived_reason: nil)

    render partial: "shared/action-feedback", locals: {
      title: "Ri-attiva progetto",
      turbo_frame: params[:turbo_frame_key] || "_top",
      feedback_args: {
        title: "Progetto ri-attivato",
        subtitle: "Il progetto #{@project.name} è stato ri-attivato con successo.",
        render_content: "projects/shared/card",
        render_content_args: { project: @project },
        type: "success"
      }
    }
  end

  def destroy_action
    return unless validate_policy!("projects_destroy")
    return unless project_finder

    @project.projects_events.destroy_all # HACK: a volte la cancellazione automatica non funziona
    @project.destroy

    render partial: "shared/action-feedback", locals: {
      title: "Elimina progetto",
      turbo_frame: params[:turbo_frame_key] || "_top",
      feedback_args: {
        title: "Progetto eliminato",
        subtitle: "Il progetto #{@project.name} è stato eliminato.",
        type: "success"
      }
    }
  end

  def add_procedure_action
    return unless validate_policy!("projects_manage_procedures")
    return unless project_finder

    procedure_clone = @project.procedures_valid.find(params[:procedure_id])
    @procedure = @project.procedures.new
    return render "projects/actions/add_procedure" unless @procedure.clone(procedure_clone, params[:name], params.permit(:deadline, :user_id))

    render partial: "shared/action-feedback", locals: {
      title: "Aggiungi board",
      turbo_frame: "module-procedures",
      feedback_args: {
        title: "Board aggiunto al progetto",
        subtitle: "La board #{@procedure.name} è stata aggiunta al progetto.",
        render_content: "procedures/shared/card",
        render_content_args: { procedure: @procedure },
        type: "success"
      }
    }
  end

  def add_procedures_item_action
    return unless validate_policy!("projects_manage_procedures_items")
    return unless project_finder

    @procedures_item = @project.procedures_items.new(params.permit(:procedure_id))
    return render "projects/actions/add_procedures_item" unless @procedures_item.save

    render partial: "shared/action-feedback", locals: {
      title: "Aggiungi ad una board",
      turbo_frame: "module-procedures-items",
      feedback_args: {
        title: "Progetto aggiunto alla board",
        subtitle: "Il progetto #{@project.name} è stato correttamente aggiunto alla board #{@procedures_item.procedure.name}.",
        type: "success"
      }
    }
  end

  # MEMBERS
  ################################################################################

  def add_member_action
    return unless validate_policy!("projects_manage_members")
    return unless project_finder

    @member = @project.projects_members.new(user_id: params[:user_id], role: params[:role])
    return render "projects/actions/add_member" unless @member.save

    render partial: "shared/action-feedback", locals: {
      title: "Aggiungi partecipante",
      turbo_frame: "module-members",
      feedback_args: {
        title: "Partecipante aggiunto",
        subtitle: "L'utente #{@member.user.complete_name} è ora parte del progetto.",
        type: "success"
      }
    }
  end

  def edit_member_action
    return unless validate_policy!("projects_manage_members")
    return unless project_finder
    return unless projects_member_finder

    return render "projects/actions/edit_member" unless @member.update(role: params[:role])

    render partial: "shared/action-feedback", locals: {
      title: "Modifica partecipante",
      turbo_frame: "module-members",
      feedback_args: {
        title: "Partecipante modificato",
        subtitle: "La partecipazione di #{@member.user.complete_name} è stata modificata correttamente.",
        type: "success"
      }
    }
  end

  def remove_member_action
    return unless validate_policy!("projects_manage_members")
    return unless project_finder
    return unless projects_member_finder

    @member.destroy

    render partial: "shared/action-feedback", locals: {
      title: "Rimuovi partecipante",
      turbo_frame: "module-members",
      feedback_args: {
        title: "Partecipante rimosso",
        subtitle: "L'utente #{@member.user.complete_name} non è più parte del progetto.",
        type: "success"
      }
    }
  end

  # LOGS
  ################################################################################

  def add_log_action
    return unless validate_policy!("projects_manage_logs")
    return unless project_finder

    @log = @project.projects_logs.new(params.permit(:title, :date, :content).merge(user_id: @session_user_id))
    return render "projects/actions/add_log" unless @log.save

    render partial: "shared/action-feedback", locals: {
      title: "Aggiungi nota",
      turbo_frame: "module-logs",
      feedback_args: {
        title: "Nota aggiunta",
        subtitle: "La nota è stata aggiunta correttamente",
        type: "success"
      }
    }
  end

  def edit_log_action
    return unless validate_policy!("projects_manage_logs")
    return unless project_finder
    return unless projects_log_finder

    return render "projects/actions/edit_log" unless @log.update(params.permit(:title, :content, :date))

    render partial: "shared/action-feedback", locals: {
      title: "Modifica nota",
      turbo_frame: "module-logs",
      feedback_args: {
        title: "Nota modificata",
        subtitle: "La nota è stata modificata correttamente",
        type: "success"
      }
    }
  end

  def share_log_action
    return unless validate_policy!("projects_manage_logs")
    return unless project_finder
    return unless projects_log_finder

    return render "projects/actions/share_log" unless @log.update(share_code: SecureRandom.hex(10))

    render partial: "shared/action-feedback", locals: {
      title: "Condividi nota",
      turbo_frame: "module-logs",
      feedback_args: {
        title: "Nota pubblicata",
        subtitle: "La nota è stata pubblicata. Di seguito trovi il link per condividerla in sicurezza.",
        type: "success",
        render_content: "projects/shared/log-share",
        render_content_args: { log: @log }
      }
    }
  end

  def unshare_log_action
    return unless validate_policy!("projects_manage_logs")
    return unless project_finder
    return unless projects_log_finder

    return render "projects/actions/share_log" unless @log.update(share_code: nil)

    render partial: "shared/action-feedback", locals: {
      title: "Annulla condivisione log",
      turbo_frame: "module-logs",
      feedback_args: {
        title: "Nota non più pubblicata",
        subtitle: "La nota non è più pubblica. Da questo momento il link di condivisione non è più attivo.",
        type: "success"
      }
    }
  end

  def remove_log_action
    return unless validate_policy!("projects_manage_logs")
    return unless project_finder
    return unless projects_log_finder

    @log.destroy

    render partial: "shared/action-feedback", locals: {
      title: "Rimuovi nota",
      turbo_frame: "module-logs",
      feedback_args: {
        title: "Nota rimossa",
        subtitle: "La nota è stata rimossa correttamente",
        type: "success"
      }
    }
  end

  # ATTACHMENTS
  ################################################################################

  def add_attachment_action
    return unless validate_policy!("projects_manage_attachments")
    return unless project_finder

    @attachment = @project.projects_attachments.new(params.permit(:typology, :version, :file, :title, :description, :date))
    return render "projects/actions/add_attachment" unless @attachment.save

    render partial: "shared/action-feedback", locals: {
      title: "Aggiungi allegato",
      turbo_frame: "module-attachments",
      feedback_args: {
        title: "Allegato aggiunto",
        subtitle: "L'allegato è stato aggiunto correttamente",
        type: "success"
      }
    }
  end

  def edit_attachment_action
    return unless validate_policy!("projects_manage_attachments")
    return unless project_finder
    return unless projects_attachment_finder

    return render "projects/actions/edit_attachment" unless @attachment.update(params.permit(:typology, :version, :file, :title, :description, :date))

    render partial: "shared/action-feedback", locals: {
      title: "Modifica allegato",
      turbo_frame: "module-attachments",
      feedback_args: {
        title: "Allegato memorizzato",
        subtitle: "L'allegato è stato modificato correttamente",
        type: "success"
      }
    }
  end

  def remove_attachment_action
    return unless validate_policy!("projects_manage_attachments")
    return unless project_finder
    return unless projects_attachment_finder

    @attachment.destroy

    render partial: "shared/action-feedback", locals: {
      title: "Rimuovi allegato",
      turbo_frame: "module-attachments",
      feedback_args: {
        title: "Allegato rimosso",
        subtitle: "L'allegato è stato rimosso correttamente",
        type: "success"
      }
    }
  end

  private

  def project_params
    params.permit(:code, :name, :year, :description, :budget_management, :budget_money, :budget_time)
  end

  def project_finder
    @project = query_projects_for_policy.find_by(id: params[:id])
    unless @project
      flash[:danger] = "Progetto non trovato o non accessibile"
      redirect_to projects_path
      return false
    end

    true
  end

  def projects_member_finder
    @member = @project.projects_members.find_by(id: params[:member_id])
    unless @member
      flash[:danger] = "Partecipante non trovato"
      redirect_to projects_show_path(@project)
      return false
    end

    true
  end

  def projects_log_finder
    @log = @project.projects_logs.find_by(id: params[:log_id])
    unless @log
      flash[:danger] = "Log non trovato"
      redirect_to projects_show_path(@project)
      return false
    end

    true
  end

  def projects_attachment_finder
    @attachment = @project.projects_attachments.find_by(id: params[:attachment_id])
    unless @attachment
      flash[:danger] = "Allegato non trovato"
      redirect_to projects_show_path(@project)
      return false
    end

    true
  end
end
