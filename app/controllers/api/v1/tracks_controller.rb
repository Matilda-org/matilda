# frozen_string_literal: true

# Tracks API: read access to time tracking entries.
class Api::V1::TracksController < Api::V1::BaseController
  # GET /api/v1/tracks
  def index
    return unless require_policy!("tasks_index")

    tracks = Tasks::Track.where(task_id: query_tasks_for_policy.select(:id)).order(start_at: :desc)
    tracks = tracks.where(user_id: params[:user_id]) if params[:user_id].present?
    tracks = tracks.where(task_id: params[:task_id]) if params[:task_id].present?
    tracks = tracks.where(start_at: Date.parse(params[:date]).all_day) if params[:date].present?
    render_paginated(tracks)
  rescue Date::Error
    render json: { error: "Formato data non valido (atteso YYYY-MM-DD)" }, status: :bad_request
  end
end
