class Folders::Item < ApplicationRecord
  include Cachable

  # RELATIONS
  ############################################################

  belongs_to :folder, optional: true
  belongs_to :resource, polymorphic: true

  # HOOKS
  ############################################################

  after_save :refresh_resource_cache
  after_destroy :refresh_resource_cache
  after_save :refresh_folder_counters
  after_destroy :refresh_folder_counters

  private

  def refresh_folder_counters
    folder.update_columns(
      items_projects_count: folder.folders_items.where(resource_type: "Project").count,
      items_credentials_count: folder.folders_items.where(resource_type: "Credential").count
    )
  end

  def refresh_resource_cache
    resource.cached_folder_item_data(true)
  end
end
