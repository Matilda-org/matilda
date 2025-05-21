# frozen_string_literal: true

# PostsController.
class PostsController < ApplicationController
  before_action :validate_session_user!
  before_action do
    @_navbar = "posts"
  end

  caches_action :index, cache_path: -> { current_cache_action_path }, layout: false
  def index
    return unless validate_policy!("posts_index")

    query = Post.all
    query = query.search(params[:search]) unless params[:search].blank?
    query = query.search(params[:tags]) unless params[:tags].blank?
    query = query.order("posts.created_at DESC")
    @posts_preferred = query.user_preferred(@session_user_id)

    @posts = paginate_query(query.where.not(id: @posts_preferred.pluck(:id)))

    # load tags
    @tags = []
    Post.all.order("created_at DESC").limit(50).each do |post|
      post.tags.split(" ").each do |tag|
        @tags << tag
      end
    end
    @tags = @tags.uniq.sample(50).sort
  end

  caches_action :actions, cache_path: -> { current_cache_action_path }, layout: false
  def actions
    @type = params[:type]
    @post = params[:id].present? ? Post.find(params[:id]) : Post.new

    return render "posts/actions/create" if @type == "create"
    return render "posts/actions/edit" if @type == "edit"
    return render "posts/actions/destroy" if @type == "destroy"

    render partial: "shared/action-error"
  end

  def create_action
    return unless validate_policy!("posts_create")

    @post = Post.new(post_params)
    return render "posts/actions/create" unless @post.save

    render partial: "shared/action-feedback", locals: {
      title: "Nuovo articolo",
      turbo_frame: "page-index",
      feedback_args: {
        title: "Articolo creato",
        subtitle: "L'articolo è stato creato con successo'.",
        type: "success"
      }
    }
  end

  def edit_action
    return unless validate_policy!("posts_edit")
    return unless post_finder

    return render "posts/actions/edit" unless @post.update(post_params)

    render partial: "shared/action-feedback", locals: {
      title: "Modifica articolo",
      turbo_frame: "_top",
      feedback_args: {
        title: "Articolo aggiornato",
        subtitle: "L'articolo è stato aggiornato con successo.",
        type: "success"
      }
    }
  end

  def destroy_action
    return unless validate_policy!("posts_destroy")
    return unless post_finder

    @post.destroy

    render partial: "shared/action-feedback", locals: {
      title: "Elimina articolo",
      turbo_frame: "_top",
      feedback_args: {
        title: "Articolo eliminato",
        subtitle: "L'articolo è stato eliminato.",
        type: "success"
      }
    }
  end

  private

  def post_params
    params.permit(:content, :tags, :source_url, :image).merge(user_id: @session_user_id)
  end

  def post_finder
    @post = Post.find_by(id: params[:id])
    unless @post
      flash[:danger] = "Post non trovato"
      redirect_to posts_path
      return false
    end

    true
  end
end
