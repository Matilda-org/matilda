class Presentations::Page < ApplicationRecord
  include Cachable

  # VALIDATIONS
  ############################################################

  validates :title, presence: true, length: { maximum: 200 }

  # RELATIONS
  ############################################################

  belongs_to :presentation

  has_many :presentations_actions, dependent: :destroy, class_name: "Presentations::Action", foreign_key: :presentations_page_id
  has_many :presentations_notes, dependent: :destroy, class_name: "Presentations::Note", foreign_key: :presentations_page_id

  has_one_attached :image

  # HOOKS
  ############################################################

  before_validation do
    self.title = capitalize_first_char(title) if title.present?
  end

  before_create do
    default_order = (presentation.presentations_pages.pluck(:order).max || 0) + 1
    self.order = default_order
  end

  # HELPERS
  ############################################################

  def image_thumb
    image.variant(resize: "300x300")
  end

  def image_preview
    image.variant(resize_to_limit: [ presentation.width_px, nil ])
  end

  # OPERATIONS
  ############################################################

  def move(new_order)
    new_order = new_order.to_i

    ActiveRecord::Base.transaction do
      pages = presentation.presentations_pages.order(order: :asc).where.not(id: id)

      # update pages order
      sum = 1
      pages.each_with_index do |page, index|
        sum += 1 if page.order == new_order
        page.update_columns(order: index + sum)
      end

      # update page
      update!(order: new_order)
    end

    true
  rescue StandardError => e
    Rails.logger.error e
    errors.add(:base, e.message)
    false
  end
end
