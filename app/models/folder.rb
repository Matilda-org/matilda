class Folder < ApplicationRecord
  include Cachable

  # VALIDATIONS
  ############################################################

  validates :name, presence: true, length: { maximum: 50 }

  # RELATIONS
  ############################################################

  has_many :folders_items, dependent: :destroy, class_name: "Folders::Item"
  has_many :projects, through: :folders_items, source: :resource, source_type: "Project"
  has_many :credentials, through: :folders_items, source: :resource, source_type: "Credential"

  # SCOPES
  ############################################################

  scope :search, ->(search) { where("LOWER(name) LIKE ?", "%#{sanitize_sql_like(search.downcase)}%") }
  scope :with_items, -> { where(id: Folders::Item.select(:folder_id)) }
  scope :without_items, -> { where.not(id: Folders::Item.where.not(folder_id: nil).select(:folder_id)) }

  # HOOKS
  ############################################################

  after_save :refresh_items_resource_cache

  # cache updates
  after_save do
    GlobalCache.new.folders_reset
  end
  after_destroy do
    GlobalCache.new.folders_reset
  end

  # HELPERS
  ############################################################

  def total_projects
    @total_projects ||= folders_items.where(resource_type: "Project").count
  end

  def total_credentials
    @total_credentials ||= folders_items.where(resource_type: "Credential").count
  end

  def last_project
    @last_project ||= folders_items.where(resource_type: "Project").order(created_at: :desc).first.try(:resource)
  end

  def last_credential
    @last_credential ||= folders_items.where(resource_type: "Credential").order(created_at: :desc).first.try(:resource)
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
