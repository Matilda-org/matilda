module Cachable
  extend ActiveSupport::Concern

  included do
    after_save :clear_views_cache
    after_destroy :clear_views_cache
  end

  def clear_views_cache
    Rails.cache.delete_matched("views/*")
  end
end
