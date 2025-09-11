class GlobalCache
  def folders
    @folders ||= Rails.cache.fetch("GlobalCache/folders", expires_in: 7.days) do
      Folder.all.order(name: :asc).map do |folder|
        {
          name: folder.name,
          id: folder.id,
          items_projects_count: folder.items_projects_count,
          items_credentials_count: folder.items_credentials_count
        }
      end
    end
  end

  def folders_reset
    Rails.cache.delete("GlobalCache/folders")
    @folders = nil
    folders
  end
end
