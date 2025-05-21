module Folderable
  extend ActiveSupport::Concern

  included do
    has_one :folders_item, as: :resource, dependent: :destroy, class_name: "Folders::Item"
    has_one :folder, through: :folders_item

    scope :for_folder, ->(folder_id) { joins(:folders_item).where(folders_items: { folder_id: folder_id }) }
    scope :without_folder, -> { left_joins(:folders_item).where(folders_items: { folder_id: nil }) }
  end

  def cached_folder_item_data(reset = false)
    Rails.cache.delete("#{self.class.name}/cached_folder_item_data/#{id}") if reset

    @cached_folder_item_data ||= Rails.cache.fetch("#{self.class.name}/cached_folder_item_data/#{id}", expires_in: 7.days) do
      if folders_item
        {
          id: folders_item.id,
          folder_id: folders_item.folder_id,
          folder_name: folders_item.folder.name
        }
      else
        nil
      end
    end
  end
end
