Rails.application.routes.draw do
  root "application#index"
  get "service-worker.js", to: "application#serviceworker", as: "serviceworker"
  get "/ping", to: "application#ping", as: :ping
  get "cacheclear", to: "application#cacheclear", as: "cacheclear"
  get "jobsrun", to: "application#jobsrun", as: "jobsrun"

  # Authentication
  get "authentication/login", to: "authentication#login", as: "authentication_login"
  get "authentication/recover-password", to: "authentication#recover_password", as: "authentication_recover_password"
  get "authentication/update-password/:id", to: "authentication#update_password", as: "authentication_update_password"
  post "authentication/login-action", to: "authentication#login_action", as: "authentication_login_action"
  post "authentication/recover-password-action", to: "authentication#recover_password_action", as: "authentication_recover_password_action"
  post "authentication/update-password-action/:id", to: "authentication#update_password_action", as: "authentication_update_password_action"
  get "authentication/logout", to: "authentication#logout", as: "authentication_logout"

  # User
  get "users", to: "users#index", as: "users"
  get "users/show/:id", to: "users#show", as: "users_show"
  get "users/actions/:type", to: "users#actions", as: "users_actions"
  get "users/actions/:type/:id", to: "users#actions", as: "users_actions_id"
  post "users/create-action", to: "users#create_action", as: "users_create_action"
  post "users/edit-action/:id", to: "users#edit_action", as: "users_edit_action"
  post "users/edit-policies-action/:id", to: "users#edit_policies_action", as: "users_edit_policies_action"
  post "users/destroy-action/:id", to: "users#destroy_action", as: "users_destroy_action"
  post "users/toggle-prefer-action", to: "users#toggle_prefer_action", as: "users_toggle_prefer_action"

  # Project
  get "projects", to: "projects#index", as: "projects"
  get "projects/show/:id", to: "projects#show", as: "projects_show"
  get "projects/show-attachment/:id", to: "projects#show_attachment", as: "projects_show_attachment"
  get "projects/show-log/:id", to: "projects#show_log", as: "projects_show_log"
  get "projects/actions/:type", to: "projects#actions", as: "projects_actions"
  get "projects/actions/:type/:id", to: "projects#actions", as: "projects_actions_id"
  post "projects/create-action", to: "projects#create_action", as: "projects_create_action"
  post "projects/edit-action/:id", to: "projects#edit_action", as: "projects_edit_action"
  post "projects/archive-action/:id", to: "projects#archive_action", as: "projects_archive_action"
  post "projects/unarchive-action/:id", to: "projects#unarchive_action", as: "projects_unarchive_action"
  post "projects/destroy-action/:id", to: "projects#destroy_action", as: "projects_destroy_action"
  post "projects/add-procedure-action/:id", to: "projects#add_procedure_action", as: "projects_add_procedure_action"
  post "projects/add-procedures-item-action/:id", to: "projects#add_procedures_item_action", as: "projects_add_procedures_item_action"
  post "projects/add-member-action/:id", to: "projects#add_member_action", as: "projects_add_member_action"
  post "projects/edit-member-action/:id/:member_id", to: "projects#edit_member_action", as: "projects_edit_member_action"
  post "projects/remove-member-action/:id/:member_id", to: "projects#remove_member_action", as: "projects_remove_member_action"
  post "projects/add-log-action/:id", to: "projects#add_log_action", as: "projects_add_log_action"
  post "projects/edit-log-action/:id/:log_id", to: "projects#edit_log_action", as: "projects_edit_log_action"
  post "projects/share-log-action/:id/:log_id", to: "projects#share_log_action", as: "projects_share_log_action"
  post "projects/unshare-log-action/:id/:log_id", to: "projects#unshare_log_action", as: "projects_unshare_log_action"
  post "projects/remove-log-action/:id/:log_id", to: "projects#remove_log_action", as: "projects_remove_log_action"
  post "projects/add-attachment-action/:id", to: "projects#add_attachment_action", as: "projects_add_attachment_action"
  post "projects/edit-attachment-action/:id/:attachment_id", to: "projects#edit_attachment_action", as: "projects_edit_attachment_action"
  post "projects/remove-attachment-action/:id/:attachment_id", to: "projects#remove_attachment_action", as: "projects_remove_attachment_action"
  get "projects/:folder_id", to: "projects#index", as: "projects_for_folder"

  # Procedure
  get "procedures", to: "procedures#index", as: "procedures"
  get "procedures/show/:id", to: "procedures#show", as: "procedures_show"
  get "procedures/actions/:type", to: "procedures#actions", as: "procedures_actions"
  get "procedures/actions/:type/:id", to: "procedures#actions", as: "procedures_actions_id"
  post "procedures/create-action", to: "procedures#create_action", as: "procedures_create_action"
  post "procedures/edit-action/:id", to: "procedures#edit_action", as: "procedures_edit_action"
  post "procedures/archive-action/:id", to: "procedures#archive_action", as: "procedures_archive_action"
  post "procedures/unarchive-action/:id", to: "procedures#unarchive_action", as: "procedures_unarchive_action"
  post "procedures/toggle-show-archived-projects-action/:id", to: "procedures#toggle_show_archived_projects_action", as: "procedures_toggle_show_archived_projects_action"
  post "procedures/clone-action/:id", to: "procedures#clone_action", as: "procedures_clone_action"
  post "procedures/destroy-action/:id", to: "procedures#destroy_action", as: "procedures_destroy_action"
  post "procedures/add-status-action/:id", to: "procedures#add_status_action", as: "procedures_add_status_action"
  post "procedures/edit-status-action/:id/:status_id", to: "procedures#edit_status_action", as: "procedures_edit_status_action"
  post "procedures/remove-status-action/:id/:status_id", to: "procedures#remove_status_action", as: "procedures_remove_status_action"
  post "procedures/move-status-action/:id/:status_id", to: "procedures#move_status_action", as: "procedures_move_status_action"
  post "procedures/toggle-status-automation-action/:id/:status_id", to: "procedures#toggle_status_automation_action", as: "procedures_toggle_status_automation_action"
  post "procedures/add-item-action/:id", to: "procedures#add_item_action", as: "procedures_add_item_action"
  post "procedures/edit-item-action/:id/:item_id", to: "procedures#edit_item_action", as: "procedures_edit_item_action"
  post "procedures/remove-item-action/:id/:item_id", to: "procedures#remove_item_action", as: "procedures_remove_item_action"
  post "procedures/move-item-action/:id/:item_id", to: "procedures#move_item_action", as: "procedures_move_item_action"

  # Posts
  get "posts", to: "posts#index", as: "posts"
  get "posts/actions/:type", to: "posts#actions", as: "posts_actions"
  post "posts/create-action", to: "posts#create_action", as: "posts_create_action"
  post "posts/edit-action/:id", to: "posts#edit_action", as: "posts_edit_action"
  post "posts/destroy-action/:id", to: "posts#destroy_action", as: "posts_destroy_action"

  # Presentation
  get "presentations", to: "presentations#index", as: "presentations"
  get "presentations/show/:id", to: "presentations#show", as: "presentations_show"
  get "presentations/player/:id", to: "presentations#player", as: "presentations_player"
  get "presentations/actions/:type", to: "presentations#actions", as: "presentations_actions"
  get "presentations/actions/:type/:id", to: "presentations#actions", as: "presentations_actions_id"
  post "presentations/create-action", to: "presentations#create_action", as: "presentations_create_action"
  post "presentations/edit-action/:id", to: "presentations#edit_action", as: "presentations_edit_action"
  post "presentations/import-action/:id", to: "presentations#import_action", as: "presentations_import_action"
  post "presentations/destroy-action/:id", to: "presentations#destroy_action", as: "presentations_destroy_action"
  post "presentations/share-action/:id", to: "presentations#share_action", as: "presentations_share_action"
  post "presentations/unshare-action/:id", to: "presentations#unshare_action", as: "presentations_unshare_action"
  post "presentations/add-page-action/:id", to: "presentations#add_page_action", as: "presentations_add_page_action"
  post "presentations/edit-page-action/:id/:page_id", to: "presentations#edit_page_action", as: "presentations_edit_page_action"
  post "presentations/remove-page-action/:id/:page_id", to: "presentations#remove_page_action", as: "presentations_remove_page_action"
  post "presentations/move-page-action/:id/:page_id", to: "presentations#move_page_action", as: "presentations_move_page_action"
  post "presentations/add-action-action/:id", to: "presentations#add_action_action", as: "presentations_add_action_action"
  post "presentations/remove-action-action/:id", to: "presentations#remove_action_action", as: "presentations_remove_action_action"
  post "presentations/add-note-action/:id", to: "presentations#add_note_action", as: "presentations_add_note_action"
  post "presentations/remove-note-action/:id", to: "presentations#remove_note_action", as: "presentations_remove_note_action"

  # Task
  get "tasks", to: "tasks#index", as: "tasks"
  get "tasks/show/:id", to: "tasks#show", as: "tasks_show"
  get "tasks/actions/:type", to: "tasks#actions", as: "tasks_actions"
  get "tasks/actions/:type/:id", to: "tasks#actions", as: "tasks_actions_id"
  post "tasks/create-action", to: "tasks#create_action", as: "tasks_create_action"
  post "tasks/edit-action/:id", to: "tasks#edit_action", as: "tasks_edit_action"
  post "tasks/destroy-action/:id", to: "tasks#destroy_action", as: "tasks_destroy_action"
  post "tasks/complete-action/:id", to: "tasks#complete_action", as: "tasks_complete_action"
  post "tasks/postpone-action/:id", to: "tasks#postpone_action", as: "tasks_postpone_action"
  post "tasks/uncomplete-action/:id", to: "tasks#uncomplete_action", as: "tasks_uncomplete_action"
  post "tasks/start-track-action/:id", to: "tasks#start_track_action", as: "tasks_start_track_action"
  post "tasks/ping-track-action/:id/:track_id", to: "tasks#ping_track_action", as: "tasks_ping_track_action"
  post "tasks/end-track-action/:id/:track_id", to: "tasks#end_track_action", as: "tasks_end_track_action"
  post "tasks/toggle-check-action/:id/:check_id", to: "tasks#toggle_check_action", as: "tasks_toggle_check_action"
  get "tasks/resume-per-inputdate", to: "tasks#resume_per_inputdate", as: "tasks_resume_per_inputdate"

  # Credentials
  get "credentials", to: "credentials#index", as: "credentials"
  get "credentials/actions/:type", to: "credentials#actions", as: "credentials_actions"
  get "credentials/actions/:type/:id", to: "credentials#actions", as: "credentials_actions_id"
  post "credentials/set-phrase-action", to: "credentials#set_phrase_action", as: "credentials_set_phrase_action"
  post "credentials/create-action", to: "credentials#create_action", as: "credentials_create_action"
  post "credentials/edit-action/:id", to: "credentials#edit_action", as: "credentials_edit_action"
  post "credentials/destroy-action/:id", to: "credentials#destroy_action", as: "credentials_destroy_action"
  get "credentials/:folder_id", to: "credentials#index", as: "credentials_for_folder"

  # Folders
  get "folders/show/:id", to: "folders#show", as: "folders_show"
  get "folders/actions/:type", to: "folders#actions", as: "folders_actions"
  get "folders/actions/:type/:id", to: "folders#actions", as: "folders_actions_id"
  post "folders/create-action", to: "folders#create_action", as: "folders_create_action"
  post "folders/edit-action/:id", to: "folders#edit_action", as: "folders_edit_action"
  post "folders/destroy-action/:id", to: "folders#destroy_action", as: "folders_destroy_action"
  post "folders/manage-resource-action", to: "folders#manage_resource_action", as: "folders_manage_resource_action"

  # Settings
  get "settings", to: "settings#index", as: "settings"
  post "settings/edit-infos-action", to: "settings#edit_infos_action", as: "settings_edit_infos_action"
  post "settings/edit-functionalities-action", to: "settings#edit_functionalities_action", as: "settings_edit_functionalities_action"
  post "settings/edit-vectorsearch-action", to: "settings#edit_vectorsearch_action", as: "settings_edit_vectorsearch_action"
  post "settings/edit-slack-action", to: "settings#edit_slack_action", as: "settings_edit_slack_action"
  post "settings/reset-action", to: "settings#reset_action", as: "settings_reset_action"

  # Tools
  get "tools", to: "tools#index", as: "tools"
  get "projects_without_procedures", to: "tools#projects_without_procedures", as: "tools_projects_without_procedures"
  get "projects_tasks_tracking", to: "tools#projects_tasks_tracking", as: "tools_projects_tasks_tracking"

  # Slack
  post "slack/search-project-attachment", to: "slack#search_project_attachment", as: "slack_search_project_attachment"
  post "slack/search-project-log", to: "slack#search_project_log", as: "slack_search_project_log"

  # Vectorsearch
  get "vectorsearch/chat", to: "vectorsearch#chat", as: "vectorsearch_chat"
  post "vectorsearch/send-message", to: "vectorsearch#send_message", as: "vectorsearch_send_message"
  post "vectorsearch/clear-messages", to: "vectorsearch#clear_messages", as: "vectorsearch_clear_messages"
  post "vectorsearch/text-to-checklist", to: "vectorsearch#text_to_checklist", as: "vectorsearch_text_to_checklist"
  post "vectorsearch/url-to-data", to: "vectorsearch#url_to_data", as: "vectorsearch_url_to_data"

  # APIs
  ##

  scope "apis", as: "apis" do
    get "procedures/:id", to: "apis#procedure", as: "procedure"
  end
end
