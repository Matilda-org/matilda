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

  private

  def refresh_resource_cache
    resource.cached_folder_item_data(true)
  end
end
