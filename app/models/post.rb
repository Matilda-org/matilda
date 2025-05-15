class Post < ApplicationRecord
  include Cachable
  include UserPreferrable

  # RELATIONS
  ############################################################

  belongs_to :user, optional: true

  has_one_attached :image

  # HOOKS
  ############################################################

  before_validation do
    unless tags.blank?
      final_tags = tags.split(',').join(' ')
      final_tags = final_tags.split(' ').map(&:strip)
      final_tags = final_tags.map { |t| t.gsub('#', '') }
      final_tags = final_tags.map { |t| "##{t}" }
      final_tags = final_tags.uniq.join(' ')
      self.tags = final_tags
    end
  end

  # SCOPES
  ############################################################

  scope :search, ->(search) { where('LOWER(posts.content) LIKE :search OR LOWER(posts.tags) LIKE :search', search: "%#{search.downcase}%") }

  # HELPERS
  ############################################################

  def image_thumb
    image.variant(resize: '300x300')
  end

  def image_large
    image.variant(resize: '900x900')
  end
end
