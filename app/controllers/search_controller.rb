# frozen_string_literal: true

# Navbar search palette: a few grouped matches per section, the full list
# stays on the dashboard search module. Not cached: results must follow edits
# right away and each query string would be its own cache entry anyway.
class SearchController < ApplicationController
  PALETTE_LIMIT = 5
  PALETTE_GROUPS = %i[projects tasks procedures credentials].freeze

  before_action :validate_session_user!

  def index
    @global_search = GlobalSearch.new(params[:q],
      user: @session_user,
      projects: query_projects_for_policy,
      tasks: query_tasks_for_policy,
      procedures: query_procedures_for_policy,
      limit: PALETTE_LIMIT
    )
    @results = @global_search.results.slice(*PALETTE_GROUPS).transform_values(&:load_async)

    render layout: false
  end
end
