class Folder < ApplicationRecord
  include Cachable

  # VALIDATIONS
  ############################################################

  validates :name, presence: true, length: { maximum: 50 }

  # RELATIONS
  ############################################################

  has_many :folders_items, dependent: :destroy, class_name: 'Folders::Item'
  has_many :projects, through: :folders_items, source: :resource, source_type: 'Project'
  has_many :credentials, through: :folders_items, source: :resource, source_type: 'Credential'

  # HOOKS
  ############################################################

  after_save :refresh_items_resource_cache

  # cache updates
  after_save do
    Folder.cached_list(true)
  end
  after_destroy do
    Folder.cached_list(true)
  end

  # HELPERS
  ############################################################

  def total_projects
    @total_projects ||= folders_items.where(resource_type: 'Project').count
  end

  def total_credentials
    @total_credentials ||= folders_items.where(resource_type: 'Credential').count
  end

  def last_project
    @last_project ||= folders_items.where(resource_type: 'Project').order(created_at: :desc).first.try(:resource)
  end

  def last_credential
    @last_credential ||= folders_items.where(resource_type: 'Credential').order(created_at: :desc).first.try(:resource)
  end

  # CLASS
  ############################################################

  def self.cached_list(reset = false)
    Rails.cache.delete("Folder/cached_list") if reset

    @cached_list ||= Rails.cache.fetch("Folder/cached_list", expires_in: 7.days) do
      Folder.all.order(name: :asc).map do |folder|
        {
          name: folder.name,
          id: folder.id
        }
      end
    end
  end

  private

  def refresh_items_resource_cache
    folders_items.find_in_batches do |batch|
      batch.each do |item|
        item.resource.cached_folder_item_data(true)
      end
    end
  end
end
