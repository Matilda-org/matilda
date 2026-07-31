# frozen_string_literal: true

# Posts API: read and create posts (bacheca).
class Api::V1::PostsController < Api::V1::BaseController
  # GET /api/v1/posts
  def index
    return unless require_policy!("posts_index")

    posts = Post.order(created_at: :desc)
    posts = posts.search(params[:search]) if params[:search].present?
    render_paginated(posts)
  end

  # POST /api/v1/posts
  def create
    return unless require_policy!("posts_create")

    post = Post.new(params.permit(:content, :tags))
    post.user_id = @current_user.id
    return render_record_errors(post) unless post.save

    render json: post.as_json, status: :created
  end
end
