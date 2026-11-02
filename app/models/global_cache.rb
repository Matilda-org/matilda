class GlobalCache
  # bump the version when the cached shape changes, so old entries are ignored
  FOLDERS_KEY = "GlobalCache/folders/v2".freeze

  def folders
    @folders ||= Rails.cache.fetch(FOLDERS_KEY, expires_in: 7.days) do
      active_projects_counts = Folders::Item.joins("INNER JOIN projects ON projects.id = folders_items.resource_id")
        .where(resource_type: "Project", projects: { archived: false })
        .group(:folder_id).count

      Folder.all.order(name: :asc).map do |folder|
        {
          name: folder.name,
          id: folder.id,
          items_projects_count: folder.items_projects_count,
          items_active_projects_count: active_projects_counts[folder.id] || 0,
          items_credentials_count: folder.items_credentials_count
        }
      end
    end
  end

  def folders_reset
    Rails.cache.delete(FOLDERS_KEY)
    @folders = nil
    folders
  end
end
