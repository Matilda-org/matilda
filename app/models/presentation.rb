class Presentation < ApplicationRecord
  include Cachable

  # RELATIONS
  ############################################################

  has_many :presentations_pages, dependent: :destroy, class_name: "Presentations::Page"
  has_many :presentations_actions, dependent: :destroy, class_name: "Presentations::Action"
  has_many :presentations_notes, dependent: :destroy, class_name: "Presentations::Note"

  belongs_to :project, optional: true

  # VALIDATIONS
  ############################################################

  validates :name, presence: true, length: { maximum: 50 }
  validates :width_px, presence: true
  validates :height_px, presence: true

  # HELPERS
  ############################################################

  def shareable?
    share_code.present?
  end

  # OPERATIONS
  ############################################################

  def import(images)
    return false unless images

    pages_to_add = []
    pages_to_edit = []

    images.each do |image|
      page = presentations_pages.find_by(image_name: image.original_filename)
      if page
        pages_to_edit << { page: page, image: image }
      else
        pages_to_add << { title: image.original_filename, image_name: image.original_filename, image: image }
      end
    end

    ActiveRecord::Base.transaction do
      pages_to_add.each do |page|
        presentations_pages.create!(page)
      end

      pages_to_edit.each do |page|
        page[:page].update!(image: page[:image])
      end
    end

    true
  rescue StandardError => e
    Rails.logger.error e
    errors.add(:base, e.message)
    false
  end
end
