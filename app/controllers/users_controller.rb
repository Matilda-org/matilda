# frozen_string_literal: true

# UsersController.
class UsersController < ApplicationController
  before_action :validate_session_user!
  before_action do
    @_navbar = 'users'
  end
  before_action :user_finder_for_show, only: :show

  caches_action :index, cache_path: -> { current_cache_action_path }, layout: false
  def index
    return unless validate_policy!('users_index')

    query = User.all
    query = query.where('LOWER(name) LIKE :search OR LOWER(surname) LIKE :search OR LOWER(email) LIKE :search', search: "%#{params[:search].downcase}%") unless params[:search].blank?
    query = query.order(surname: :asc, name: :asc)
    @users = paginate_query(query)
  end

  caches_action :show, cache_path: -> { current_cache_action_path }, layout: false
  def show
    return unless @_is_dashboard || validate_policy!('users_show')

    # load general data
    @projects = @user.projects_as_member.not_archived.order(name: :asc).sort_by { |p| p.user_prefer?(@session_user)  ? -1 : 1 }
    @tasks = @user.tasks.not_completed.includes(:project, :procedures_as_item).order(deadline: :asc, alghoritmic_order: :asc, title: :asc)
    @tasks = @tasks.where(project_id: params[:tasks_project_id]) if params[:tasks_project_id]
    @tasks_projects = Project.joins(:tasks).where(tasks: { user_id: @user.id, completed: false }).includes(folders_item: :folder).select('projects.*, COUNT(tasks.id) AS _total_tasks').group('projects.id').sort_by { |p| p._total_tasks }.reverse
    @tasks_followed = Task.joins(:tasks_followers).where(tasks_followers: { user_id: @user.id }).not_completed.order(deadline: :asc, alghoritmic_order: :asc, title: :asc)

    # manage search
    if params[:search] && params[:search].length >= 3
      @search = params[:search]
      @search_results = {}
      @search_results[:projects] = Project.not_archived.search(params[:search]).order(name: :asc).limit(25).load_async
      @search_results[:credentials] = Credential.search(params[:search]).order(name: :asc).limit(25).load_async
      @search_results[:tasks] = Task.not_completed.search(params[:search]).order(deadline: :asc, alghoritmic_order: :asc, title: :asc).limit(25).load_async
      @search_results[:procedures] = Procedure.not_as_model.not_archived.search(params[:search]).where(projects: { archived: [nil, false] }).order(name: :asc).limit(25).load_async
      @search_results[:projects_archived] = Project.archived.search(params[:search]).order(name: :asc).limit(25).load_async

      if @search_results[:projects].count.positive? || @search_results[:credentials].count.positive? || @search_results[:tasks].count.positive? || @search_results[:procedures].count.positive?
        @session_user.log_search(@search)
      end
    end
  end

  caches_action :actions, cache_path: -> { current_cache_action_path }, layout: false
  def actions
    @type = params[:type]
    @user = params[:id].present? ? User.find(params[:id]) : User.new

    return render 'users/actions/create' if @type == 'create'
    return render 'users/actions/edit' if @type == 'edit'
    return render 'users/actions/edit_policies' if @type == 'edit-policies'
    return render 'users/actions/destroy' if @type == 'destroy'

    render partial: 'shared/action-error'
  end

  def create_action
    return unless validate_policy!('users_create')

    password = SecureRandom.hex(8).upcase
    @user = User.new(user_params.merge(password: password, password_confirmation: password))
    return render 'users/actions/create' unless @user.save

    render partial: 'shared/action-feedback', locals: {
      title: 'Nuovo utente',
      turbo_frame: 'page-index',
      feedback_args: {
        title: 'Utente creato',
        subtitle: "L'utente #{@user.complete_name} è stato creato con successo. La sua password di accesso è <b>#{password}</b>.",
        render_content: 'users/shared/card',
        render_content_args: { user: @user },
        type: 'success'
      }
    }
  end

  def edit_action
    return unless validate_policy!('users_edit')
    return unless user_finder

    return render 'users/actions/edit' unless @user.update(user_params)

    render partial: 'shared/action-feedback', locals: {
      title: 'Modifica utente',
      turbo_frame: 'page-header',
      feedback_args: {
        title: 'Utente aggiornato',
        subtitle: "L'utente #{@user.complete_name} è stato aggiornato con successo.",
        render_content: 'users/shared/card',
        render_content_args: { user: @user },
        type: 'success'
      }
    }
  end

  def edit_policies_action
    return unless validate_policy!('users_edit_policies')
    return unless user_finder

    return render 'users/actions/edit' unless @user.update_policies(params.permit(policies: [])[:policies])

    render partial: 'shared/action-feedback', locals: {
      title: 'Modifica permessi utente',
      turbo_frame: 'page-header',
      feedback_args: {
        title: 'Permessi utente aggiornati',
        subtitle: "I permessi di #{@user.complete_name} sono stati aggiornati con successo.",
        type: 'success'
      }
    }
  end

  def destroy_action
    return unless validate_policy!('users_destroy')
    return unless user_finder

    @user.destroy

    render partial: 'shared/action-feedback', locals: {
      title: 'Elimina utente',
      turbo_frame: '_top',
      feedback_args: {
        title: 'Utente eliminato',
        subtitle: "L'utente #{@user.complete_name} è stato eliminato e non potrà più accedere.",
        type: 'success'
      }
    }
  end

  # PREFERS
  ################################################################################

  def toggle_prefer_action
    prefer = @session_user.users_prefers.find_by(resource_id: params[:resource_id], resource_type: params[:resource_type])
    if prefer
      prefer.destroy

      render partial: 'shared/action-feedback', locals: {
        title: 'Rimuovi preferito',
        turbo_frame: '_top',
        feedback_args: {
          title: 'Preferito rimosso',
          subtitle: 'Hai tolto il preferito.',
          type: 'success'
        }
      }
    else
      @session_user.users_prefers.create(resource_id: params[:resource_id], resource_type: params[:resource_type])

      render partial: 'shared/action-feedback', locals: {
        title: 'Aggiungi preferito',
        turbo_frame: '_top',
        feedback_args: {
          title: 'Preferito aggiunto',
          subtitle: 'Hai aggiunto il preferito.',
          type: 'success'
        }
      }
    end
  end

  private

  def user_params
    params.permit(:name, :surname, :email, :image_profile)
  end

  def user_finder
    return true if @user

    # HACK: Save a query
    if @session_user_id == params[:id]&.to_i
      @user = @session_user
      return true
    end

    @user = User.find_by(id: params[:id])
    unless @user
      flash[:danger] = 'Utente non trovato'
      redirect_to users_path
      return false
    end

    true
  end

  def user_finder_for_show
    return unless user_finder

    @_is_dashboard = @user.id == @session_user_id
    @_navbar = 'dashboard' if @_is_dashboard
  end
end
