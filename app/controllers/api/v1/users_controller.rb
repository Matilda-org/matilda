# frozen_string_literal: true

# Users API: read-only access to users plus the authenticated user profile.
class Api::V1::UsersController < Api::V1::BaseController
  # GET /api/v1/me — no policy: every API key can read its own profile
  def me
    render json: @current_user.as_json(methods: [ :policies ])
  end

  # GET /api/v1/users
  def index
    return unless require_policy!("users_index")

    render_paginated(User.order(surname: :asc, name: :asc))
  end

  # GET /api/v1/users/:id
  def show
    return unless require_policy!("users_show")

    render json: User.find(params[:id]).as_json(methods: [ :policies ])
  end
end
