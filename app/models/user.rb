class User < ApplicationRecord
  include Cachable

  # RELATIONS
  ############################################################

  has_many :users_prefers, dependent: :destroy, class_name: "Users::Prefer"
  has_many :users_policies, dependent: :destroy, class_name: "Users::Policy"
  has_many :users_logs, dependent: :destroy, class_name: "Users::Log"

  has_many :projects_members, dependent: :destroy, class_name: "Projects::Member"
  has_many :projects_as_member, through: :projects_members, source: :project
  has_many :projects_logs, dependent: :destroy, class_name: "Projects::Log"

  has_many :tasks, dependent: :destroy
  has_many :tasks_tracks, dependent: :nullify, class_name: "Tasks::Track"
  has_many :tasks_followers, dependent: :nullify, class_name: "Tasks::Follower"

  has_many :posts, dependent: :nullify

  has_many :notifications, dependent: :destroy

  has_many :procedures_statuses_assignments, dependent: :nullify, class_name: "Procedures::Status", foreign_key: :assignment_user_id
  has_many :procedures_statuses_follows, dependent: :nullify, class_name: "Procedures::Status", foreign_key: :follow_user_id

  has_one_attached :image_profile

  # VALIDATIONS
  ############################################################

  validates :name, presence: true, length: { maximum: 50 }
  validates :surname, presence: true, length: { maximum: 50 }
  validates :email, presence: true, length: { maximum: 255 }, format: { with: /\A[\w+\-.]+@[a-z\d\-.]+\.[a-z]+\z/i }, uniqueness: { case_sensitive: false }
  validates :password, presence: true, length: { minimum: 6, maximum: 25 }, on: :create
  validate :image_profile_validation
  has_secure_password

  # HOOKS
  ############################################################

  before_validation do
    self.name = capitalize_first_char(name) if name.present?
    self.surname = surname.slice(0, 1).capitalize + surname.slice(1..-1) if surname.present?
    self.email = email.downcase if email.present?
  end

  # cache updates
  after_save_commit do
    User.cached_preview_data(id, true)
  end

  # QUESTIONS
  ############################################################

  def prefer?(resource_id, resource_type)
    cached_users_prefers[resource_type] && cached_users_prefers[resource_type].include?(resource_id)
  end

  def policy?(policy)
    cached_policies&.include?(policy)
  end

  # HELPERS
  ############################################################

  def complete_name
    [ surname, name ].join(" ")
  end

  def active_tasks_track
    @active_tasks_track ||= tasks_tracks.not_closed.order(start_at: :desc).first
  end

  def daily_tasks_tracks_time_spent
    @daily_tasks_tracks_time_spent ||= tasks_tracks.where(start_at: Time.now.beginning_of_day..Time.now.end_of_day).sum do |track|
      track.duration
    end
  end

  def image_profile_thumb
    image_profile.variant(resize: "100x100")
  end

  def policies
    @policies ||= users_policies.pluck(:policy).map(&:to_s)
  end

  def projects_as_member_ids
    @projects_as_member_ids ||= projects_members.pluck(:project_id)
  end

  def cached_users_logs_search_values(reset = false)
    Rails.cache.delete("User/cached_users_logs_search_values/#{id}") if reset

    @cached_users_logs_search_values ||= Rails.cache.fetch("User/cached_users_logs_search_values/#{id}", expires_in: 7.days) do
      users_logs.search.order(created_at: :desc).limit(99).pluck(:value).uniq.first(6)
    end
  end

  def cached_users_logs_credential_values(reset = false)
    Rails.cache.delete("User/cached_users_logs_credential_values/#{id}") if reset

    @cached_users_logs_credential_values ||= Rails.cache.fetch("User/cached_users_logs_credential_values/#{id}", expires_in: 7.days) do
      users_logs.credential.order(created_at: :desc).limit(99).pluck(:value).uniq.first(3)
    end
  end

  def cached_users_prefers(reset = false)
    Rails.cache.delete("User/cached_users_prefers/#{id}") if reset

    @cached_users_prefers ||= Rails.cache.fetch("User/cached_users_prefers/#{id}", expires_in: 7.days) do
      data = {}
      users_prefers.pluck(:resource_type).each do |resource_type|
        data[resource_type] = users_prefers.where(resource_type: resource_type).pluck(:resource_id)
      end
      data
    end
  end

  def cached_policies(reset = false)
    Rails.cache.delete("User/cached_policies/#{id}") if reset

    @cached_policies ||= Rails.cache.fetch("User/cached_policies/#{id}", expires_in: 7.days) do
      users_policies.pluck(:policy).map(&:to_s)
    end
  end

  # OPERATIONS
  ############################################################

  def update_policies(policies)
    ActiveRecord::Base.transaction do
      users_policies.destroy_all
      policies&.each do |policy|
        users_policies.create!(policy: policy)
      end
    end

    true
  rescue StandardError => e
    Rails.logger.error e
    errors.add(:base, e.message)
    false
  end

  def log_search(search)
    users_logs.create(typology: :search, value: search)
    cached_users_logs_search_values(true)
  end

  def log_credential(credential_id)
    users_logs.create(typology: :credential, value: credential_id)
    cached_users_logs_credential_values(true)
  end

  # CLASS
  ############################################################

  def self.cached_preview_data(user_id, reset = false)
    Rails.cache.delete("User/cached_preview_data/#{user_id}") if reset

    Rails.cache.fetch("User/cached_preview_data/#{user_id}", expires_in: 7.days) do
      user = User.find_by(id: user_id)

      image_profile_url = "/statics/placeholder-profile.jpg"
      if user.image_profile.attached?
        image_profile_url = Rails.application.routes.url_helpers.url_for(user.image_profile_thumb)
      end

      {
        image_profile_url: image_profile_url,
        complete_name: user.complete_name
      }
    end
  end

  private

  def image_profile_validation
    return true unless image_profile.attached?
    return true if image_profile.content_type.in?(%('image/jpeg image/png'))

    errors.add(:image_profile, "needs to be a jpeg or png")
  end
end
