# frozen_string_literal: true

# Folders API: read access to folders and their resources.
class Api::V1::FoldersController < Api::V1::BaseController
  # GET /api/v1/folders — like the web app, folders are visible to any authenticated user
  def index
    render_paginated(Folder.order(name: :asc))
  end

  # GET /api/v1/folders/:id
  def show
    folder = Folder.find(params[:id])
    # projects inside the folder still respect the membership visibility policy
    render json: folder.as_json.merge(
      projects: query_projects_for_policy.where(id: folder.projects.select(:id)).as_json
    )
  end
end
