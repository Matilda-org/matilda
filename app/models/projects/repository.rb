class Projects::Repository < ApplicationRecord
  # The project page is action cached ("views/*"), so without this the linked
  # repository stays in the database but never shows up on the page.
  include Cachable

  enum :provider, {
    github: 0,
    gitlab: 1
  }

  # VALIDATIONS
  ############################################################

  validates :url, presence: true, length: { maximum: 255 }
  validates :url, uniqueness: { scope: :project_id, case_sensitive: false }
  validates :provider, presence: true
  validates :default_branch, length: { maximum: 100 }
  validate :url_validation

  # RELATIONS
  ############################################################

  belongs_to :project

  # HOOKS
  ############################################################

  before_validation :normalize_url
  before_validation :detect_name

  after_create :save_event_creation_on_project

  # HELPERS
  ############################################################

  def provider_string
    @provider_string ||= Projects::Repository.provider_string(provider)
  end

  # Bootstrap Icons class for the provider badge (no gitlab glyph in bootstrap-icons 1.9.1).
  def provider_icon
    provider == "gitlab" ? "bi-git" : "bi-github"
  end

  # Bootstrap color paired with #provider_icon.
  def provider_color
    provider == "gitlab" ? "warning" : "dark"
  end

  # OPERATIONS
  ############################################################

  def save_event_creation_on_project
    project.projects_events.create!(message: "Repository #{name} (#{provider_string}) - collegato al progetto.", data: {
      repository_id: id
    })
  end

  private

  # Both the https and the ssh clone url are accepted, the canonical https form is stored.
  def normalize_url
    return if url.blank?

    value = url.strip.chomp("/").delete_suffix(".git")
    value = value.sub(%r{\Agit@([^:/]+):}, 'https://\1/')
    value = "https://#{value}" unless value.match?(%r{\Ahttps?://}i)

    self.url = value
  end

  # The name is the repository path (owner/repo, or group/subgroup/repo on GitLab).
  def detect_name
    self.name = url_path.presence
  end

  def url_validation
    errors.add(:url, "non valido") if url.present? && (url_host.blank? || url_path.blank?)
  end

  def url_host
    URI.parse(url).host
  rescue URI::InvalidURIError
    nil
  end

  def url_path
    URI.parse(url).path.to_s.delete_prefix("/").presence
  rescue URI::InvalidURIError
    nil
  end

  # CLASS
  ############################################################

  def self.provider_string(provider)
    return "GitHub" if provider == "github"
    return "GitLab" if provider == "gitlab"

    "Non definito"
  end
end
