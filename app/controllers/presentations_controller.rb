# frozen_string_literal: true

# PresentationsController.
class PresentationsController < ApplicationController
  before_action :validate_session_user!, except: :player
  before_action do
    @_navbar = "presentations"
  end

  def player
    return unless presentation_finder

    @page = params[:page_id] ? @presentation.presentations_pages.find_by(id: params[:page_id]) : @presentation.presentations_pages.order(order: :asc).limit(1).first

    if !@session_user_id && !session["presentations_player_#{@presentation.id}"]
      return redirect_to authentication_login_path unless @presentation.shareable? && params[:share_code] == @presentation.share_code

      session["presentations_player_#{@presentation.id}"] = true
    end

    @_nav_title = @presentation.name
  end

  caches_action :index, cache_path: -> { current_cache_action_path }, layout: false
  def index
    return unless validate_policy!("presentations_index")

    query = Presentation.all
    query = query.where("LOWER(name) LIKE :search", search: "%#{params[:search].downcase}%") unless params[:search].blank?
    query = query.order(name: :asc)
    @presentations = paginate_query(query)
  end

  caches_action :show, cache_path: -> { current_cache_action_path }, layout: false
  def show
    return unless validate_policy!("presentations_show")
    return unless presentation_finder

    @page = params[:page_id] ? @presentation.presentations_pages.find_by(id: params[:page_id]) : @presentation.presentations_pages.order(order: :asc).limit(1).first
  end

  caches_action :actions, cache_path: -> { current_cache_action_path }, layout: false
  def actions
    @type = params[:type]
    @presentation = params[:id].present? ? Presentation.find(params[:id]) : Presentation.new

    return render "presentations/actions/create" if @type == "create"
    return render "presentations/actions/import" if @type == "import"
    return render "presentations/actions/edit" if @type == "edit"
    return render "presentations/actions/destroy" if @type == "destroy"
    if @type == "add-page"
      return unless presentation_finder
      return render "presentations/actions/add_page"
    end
    if @type == "share"
      return unless presentation_finder
      return render "presentations/actions/share"
    end
    if @type == "unshare"
      return unless presentation_finder
      return render "presentations/actions/unshare"
    end
    if @type == "edit-page"
      return unless presentation_finder
      return unless presentations_page_finder
      return render "presentations/actions/edit_page"
    end
    if @type == "remove-page"
      return unless presentation_finder
      return unless presentations_page_finder
      return render "presentations/actions/remove_page"
    end
    if @type == "add-action"
      return unless presentation_finder
      return render "presentations/actions/add_action"
    end
    if @type == "remove-action"
      return unless presentation_finder
      return unless presentations_action_finder
      return render "presentations/actions/remove_action"
    end
    if @type == "add-note"
      return unless presentation_finder
      return render "presentations/actions/add_note"
    end
    if @type == "remove-note"
      return unless presentation_finder
      return unless presentations_note_finder
      return render "presentations/actions/remove_note"
    end

    render partial: "shared/action-error"
  end

  def create_action
    return unless validate_policy!("presentations_create")

    @presentation = Presentation.new(presentation_params)
    return render "presentations/actions/create" unless @presentation.save

    render partial: "shared/action-feedback", locals: {
      title: "Nuova presentazione",
      turbo_frame: params[:turbo_frame_key] || "page-index",
      feedback_args: {
        title: "Presentazione creata",
        subtitle: "La presentazione #{@presentation.name} è stata creata con successo.",
        render_content: "presentations/shared/card",
        render_content_args: { presentation: @presentation },
        type: "success"
      }
    }
  end

  def edit_action
    return unless validate_policy!("presentations_edit")
    return unless presentation_finder

    return render "presentations/actions/edit" unless @presentation.update(presentation_params)

    render partial: "shared/action-feedback", locals: {
      title: "Modifica presentazione",
      turbo_frame: "page-header",
      feedback_args: {
        title: "Presentazione aggiornata",
        subtitle: "La presentazione #{@presentation.name} è stata aggiornata con successo.",
        render_content: "presentations/shared/card",
        render_content_args: { presentation: @presentation },
        type: "success"
      }
    }
  end

  def import_action
    return unless validate_policy!("presentations_edit")
    return unless presentation_finder

    return render "presentations/actions/import" unless @presentation.import(params[:images])

    render partial: "shared/action-feedback", locals: {
      title: "Importa pagine",
      turbo_frame: "_top",
      feedback_args: {
        title: "Pagine importate",
        subtitle: "Le pagine sono state importate correttamente.",
        type: "success"
      }
    }
  end

  def destroy_action
    return unless validate_policy!("presentations_destroy")
    return unless presentation_finder

    @presentation.destroy

    render partial: "shared/action-feedback", locals: {
      title: "Elimina presentazione",
      turbo_frame: "_top",
      feedback_args: {
        title: "Presentazione eliminata",
        subtitle: "La presentazione #{@presentation.name} è stata eliminata.",
        type: "success"
      }
    }
  end

  def share_action
    return unless validate_policy!("presentations_share")
    return unless presentation_finder

    return render "presentations/actions/share" unless @presentation.update(share_code: SecureRandom.hex(10))

    render partial: "shared/action-feedback", locals: {
      title: "Condividi presentazione",
      turbo_frame: "_top",
      feedback_args: {
        title: "Presentazione pubblicata",
        subtitle: "La presentazione è stata pubblicata. Di seguito trovi il link per condividerla in sicurezza.",
        type: "success",
        render_content: "presentations/shared/share",
        render_content_args: { presentation: @presentation }
      }
    }
  end

  def unshare_action
    return unless validate_policy!("presentations_share")
    return unless presentation_finder

    return render "presentations/actions/share" unless @presentation.update(share_code: nil)

    render partial: "shared/action-feedback", locals: {
      title: "Annulla condivisione",
      turbo_frame: "_top",
      feedback_args: {
        title: "Presentazione non più pubblicata",
        subtitle: "La presentazione non è più pubblica. Da questo momento il link di condivisione non è più attivo.",
        type: "success"
      }
    }
  end

  # PAGES
  ################################################################################

  def editor_player
    return unless validate_policy!("presentations_edit")
    return unless presentation_finder
    return unless presentations_page_finder

    render partial: "presentations/editor/player", locals: { page: @page }
  end

  def add_page_action
    return unless validate_policy!("presentations_edit")
    return unless presentation_finder

    @page = @presentation.presentations_pages.new(presentations_page_params)
    return render "presentations/actions/add_page" unless @page.save

    render partial: "shared/action-feedback", locals: {
      title: "Aggiungi pagina",
      turbo_frame: "_top",
      feedback_args: {
        title: "Pagina aggiunta",
        subtitle: "La pagina è stata aggiunta correttamente",
        type: "success"
      }
    }
  end

  def edit_page_action
    return unless validate_policy!("presentations_edit")
    return unless presentation_finder
    return unless presentations_page_finder

    return render "presentations/actions/edit_page" unless @page.update(presentations_page_params)

    render partial: "shared/action-feedback", locals: {
      title: "Modifica pagina",
      turbo_frame: "_top",
      feedback_args: {
        title: "Pagina modificata",
        subtitle: "Le modifiche alla pagina sono state salvate.",
        type: "success"
      }
    }
  end

  def remove_page_action
    return unless validate_policy!("presentations_edit")
    return unless presentation_finder
    return unless presentations_page_finder

    @page.destroy

    render partial: "shared/action-feedback", locals: {
      title: "Rimuovi pagina",
      turbo_frame: "_top",
      feedback_args: {
        title: "Pagina rimossa",
        subtitle: "La pagina non è più presente nella presentazione.",
        type: "success"
      }
    }
  end

  def move_page_action
    return unless validate_policy!("presentations_edit")
    return unless presentation_finder
    return unless presentations_page_finder

    p = params.permit(:order)
    @page.move(p[:order])

    render partial: "presentations/editor/nav-page", locals: { page: @page }
  end

  # ACTIONS
  ################################################################################

  def add_action_action
    return unless validate_policy!("presentations_edit")
    return unless presentation_finder

    @action = @presentation.presentations_actions.new(params.permit(:presentations_page_id, :position_x, :position_y, :page_destination))
    return render "presentations/actions/add_action" unless @action.save

    render partial: "shared/action-feedback", locals: {
      title: "Aggiungi azione",
      turbo_frame: "presentation-editor-player",
      feedback_args: {
        title: "Azione aggiunta",
        subtitle: "L'azione è stata aggiunta correttamente",
        type: "success"
      }
    }
  end

  def remove_action_action
    return unless validate_policy!("presentations_edit")
    return unless presentation_finder
    return unless presentations_action_finder

    @action.destroy

    render partial: "shared/action-feedback", locals: {
      title: "Rimuovi azione",
      turbo_frame: params[:turbo_frame_key] || "_top",
      feedback_args: {
        title: "Azione rimossa",
        subtitle: "La rimozione è avvenuta con successo.",
        type: "success"
      }
    }
  end

  # NOTES
  ################################################################################

  def add_note_action
    return unless validate_policy!("presentations_edit")
    return unless presentation_finder

    @note = @presentation.presentations_notes.new(params.permit(:presentations_page_id, :position_x, :position_y, :content))
    return render "presentations/actions/add_note" unless @note.save

    render partial: "shared/action-feedback", locals: {
      title: "Aggiungi nota",
      turbo_frame: "presentation-editor-player",
      feedback_args: {
        title: "Nota aggiunta",
        subtitle: "La nota è stata aggiunta correttamente",
        type: "success"
      }
    }
  end

  def remove_note_action
    return unless validate_policy!("presentations_edit")
    return unless presentation_finder
    return unless presentations_note_finder

    @note.destroy

    render partial: "shared/action-feedback", locals: {
      title: "Rimuovi nota",
      turbo_frame: params[:turbo_frame_key] || "_top",
      feedback_args: {
        title: "Nota rimossa",
        subtitle: "La rimozione è avvenuta con successo.",
        type: "success"
      }
    }
  end

  private

  def presentation_params
    params.permit(:name, :description, :width_px, :height_px, :project_id)
  end

  def presentations_page_params
    params.permit(:title, :image).merge(
      image_name: params[:image]&.original_filename
    )
  end

  def presentation_finder
    @presentation = Presentation.find_by(id: params[:id])
    unless @presentation
      flash[:danger] = "Presentazione non trovata"
      redirect_to presentations_path
      return false
    end

    true
  end

  def presentations_page_finder
    @page = @presentation.presentations_pages.find_by(id: params[:page_id])
    unless @page
      flash[:danger] = "Pagina non trovata"
      redirect_to presentations_show_path(@presentation)
      return false
    end

    true
  end

  def presentations_action_finder
    @action = @presentation.presentations_actions.find_by(id: params[:action_id])
    unless @action
      flash[:danger] = "Azione non trovata"
      redirect_to presentations_show_path(@presentation)
      return false
    end

    true
  end

  def presentations_note_finder
    @note = @presentation.presentations_notes.find_by(id: params[:note_id])
    unless @note
      flash[:danger] = "Nota non trovata"
      redirect_to presentations_show_path(@presentation)
      return false
    end

    true
  end
end
