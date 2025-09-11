class Users::Policy < ApplicationRecord
  include Cachable

  enum :policy, {
    # User # OK
    users_index: 1,
    users_show: 2,
    users_create: 3,
    users_edit: 4,
    users_edit_policies: 5,
    users_destroy: 6,

    # Projects # OK
    projects_index: 28,
    projects_show: 29,
    projects_create: 30,
    projects_destroy: 7,
    projects_archive: 8,
    projects_unarchive: 9,
    projects_edit: 10,
    projects_manage_members: 11,
    projects_manage_logs: 12,
    projects_manage_attachments: 13,
    projects_manage_procedures: 25,
    projects_manage_procedures_items: 26,
    projects_manage_presentations: 27,
    projects_manage_events: 54,

    # Folders # OK
    folders_create: 14,
    folders_edit: 15,
    folders_destroy: 16,
    folders_manage_resources: 17,

    # Tasks
    tasks_index: 18,
    tasks_show: 31,
    tasks_create: 32,
    tasks_edit: 33,
    tasks_destroy: 34,
    tasks_complete: 35,
    tasks_uncomplete: 36,
    tasks_track: 37,
    tasks_acceptance: 59,
    tasks_check: 60,

    # Procedures
    procedures_index: 19,
    procedures_show: 38,
    procedures_create: 39,
    procedures_edit: 40,
    procedures_archive: 41,
    procedures_unarchive: 42,
    procedures_clone: 43,
    procedures_destroy: 44,

    # Presentations
    presentations_index: 20,
    presentations_show: 45,
    presentations_create: 46,
    presentations_edit: 47,
    presentations_destroy: 48,
    presentations_share: 49,

    # Credentials
    credentials_index: 21,
    credentials_set_phrase: 50,
    credentials_create: 51,
    credentials_edit: 52,
    credentials_destroy: 53,

    # Posts
    posts_index: 55,
    posts_create: 56,
    posts_edit: 57,
    posts_destroy: 58,

    # Settings
    settings: 22,

    # Tools
    tools: 23,

    # LIMIT BASED ON PROJECTS
    only_data_projects_as_member: 24
  }

  # RELATIONS
  ############################################################

  belongs_to :user

  # HOOKS
  ############################################################

  # cache updates
  after_save_commit do
    user.cached_policies(true)
  end
  after_destroy_commit do
    user.cached_policies(true)
  end
end
