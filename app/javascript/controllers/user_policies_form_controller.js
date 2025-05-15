import { Controller } from "@hotwired/stimulus"

const INCLUSIONS = {
  production_internal: [
    'credentials_index',
    'credentials_create',
    'credentials_edit',
    'credentials_destroy',
    'procedures_index',
    'procedures_show',
    'procedures_create',
    'procedures_edit',
    'procedures_archive',
    'procedures_unarchive',
    'procedures_clone',
    'tasks_index',
    'tasks_show',
    'tasks_create',
    'tasks_edit',
    'tasks_destroy',
    'tasks_complete',
    'tasks_uncomplete',
    'tasks_track',
    'tasks_check',
    'folders_create',
    'folders_edit',
    'folders_destroy',
    'folders_manage_resources',
    'projects_index',
    'projects_show',
    'projects_create',
    'projects_edit',
    'projects_destroy',
    'projects_archive',
    'projects_unarchive',
    'projects_manage_members',
    'projects_manage_logs',
    'projects_manage_attachments',
    'projects_manage_procedures',
    'projects_manage_procedures_items',
    'procedures_destroy',
  ],
  production_external: [
    'only_data_projects_as_member',
    'projects_show',
    'projects_manage_procedures',
    'tasks_edit',
    'tasks_complete',
    'tasks_track',
    'tasks_check',
    'tasks_show',
    'procedures_show',
    'procedures_edit',
  ],
}

const EXCLUSIONS = {
  admin: ['only_data_projects_as_member']
}

export default class extends Controller {
  static targets = ['preset', 'policies']

  connect() {
    this.presetTarget.addEventListener('change', (e) => this.applyPreset(e.target.value))
  }

  applyPreset(value) {
    if (value == 'admin') {
      this.policiesTarget.querySelectorAll('option').forEach((option) => {
        if (EXCLUSIONS.admin.includes(option.value)) {
          option.removeAttribute('selected')
        } else {
          option.setAttribute('selected', true)
        }
      })
    } else if (value == 'production_internal') {
      this.policiesTarget.querySelectorAll('option').forEach((option) => {
        if (INCLUSIONS.production_internal.includes(option.value)) {
          option.setAttribute('selected', true)
        } else {
          option.removeAttribute('selected')
        }
      })
    } else if (value == 'production_external') {
      this.policiesTarget.querySelectorAll('option').forEach((option) => {
        if (INCLUSIONS.production_external.includes(option.value)) {
          option.setAttribute('selected', true)
        } else {
          option.removeAttribute('selected')
        }
      })
    } else {
      this.policiesTarget.querySelectorAll('option').forEach((option) => {
        option.removeAttribute('selected')
      })
    }
  }
}