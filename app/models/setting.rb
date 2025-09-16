class Setting < ApplicationRecord
  include Cachable

  has_one_attached :file

  # VALIDATIONS
  ############################################################

  validates :key, presence: true, length: { maximum: 50 }, uniqueness: { case_sensitive: false }

  # HOOKS
  ############################################################

  before_validation do
    self.key = key.downcase.parameterize if key.present?
  end

  # HELPERS
  ############################################################

  def value
    return data["value"] if data["type"] == "json"
    return data["value"]&.to_s if data["type"] == "string"
    return data["value"]&.to_i&.positive? if data["type"] == "boolean"
    return Rails.application.routes.url_helpers.url_for(file) if data["type"] == "file" && file.attached?

    nil
  end

  # CLASS
  ############################################################

  def self.get(key)
    Rails.cache.fetch("Setting/#{key}", expires_in: 7.days) do
      setting = Setting.find_by(key: key)

      setting&.value
    end
  end

  def self.set(key, val, type = "string")
    Rails.cache.delete("Setting/#{key}")

    if type == "file"
      setting = Setting.find_or_create_by(key: key)
      setting.update(data: { type: type, value: nil })
      setting.file.attach(val)
    else
      Setting.find_or_create_by(key: key).update(data: { type: type, value: val })
    end
  end

  def self.reset(key_start)
    Setting.where("key LIKE ?", "#{key_start}%").delete_all
    Rails.cache.clear
  end
end
