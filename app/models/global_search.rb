# frozen_string_literal: true

# Cross-section search shared by the dashboard search module and the navbar
# palette. Visibility comes from the caller's policy scopes (the
# `query_*_for_policy` controller helpers), so the membership limit applies.
# Results are lazy relations: callers load only the groups they render.
class GlobalSearch
  MIN_LENGTH = 3

  attr_reader :search

  def initialize(search, user:, projects:, tasks:, procedures:, limit: 25)
    @search = search.to_s.strip
    @user = user
    @projects = projects
    @tasks = tasks
    @procedures = procedures
    @limit = limit
  end

  def valid?
    search.length >= MIN_LENGTH
  end

  def results
    return {} unless valid?

    {
      projects: @projects.not_archived.search(search).order(name: :asc).limit(@limit),
      credentials: credentials.search(search).order(name: :asc).limit(@limit),
      tasks: @tasks.not_completed.search(search).order(deadline: :asc, alghoritmic_order: :asc, title: :asc).limit(@limit),
      procedures: @procedures.not_as_model.not_archived.search(search).where(projects: { archived: [ nil, false ] }).order(name: :asc).limit(@limit),
      projects_archived: @projects.archived.search(search).order(name: :asc).limit(@limit)
    }
  end

  private

  def credentials
    @user.policy?("credentials_index") ? Credential.all : Credential.none
  end
end
