class RemoveProviderDefaultFromProjectsRepositories < ActiveRecord::Migration[8.0]
  # The provider is now always picked explicitly (autofilled from the url in the form),
  # so the column must not silently fall back to github.
  def change
    change_column_default :projects_repositories, :provider, from: 0, to: nil
  end
end
