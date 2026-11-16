import { Controller } from '@hotwired/stimulus'

const STORAGE_KEY = 'sidebar-collapsed'

// Sidebar submenus use data-bs-auto-close="false" so they stay open while
// browsing them: opening one closes the others by hand, one section at a time.
// The sidebar can also shrink to an icon-only rail; the choice is remembered
// per browser and lives on <html>, which Turbo keeps across visits.
export default class extends Controller {
  static targets = ['toggle']

  connect () {
    this.applyCollapsed(this.storedCollapsed())
  }

  closeOthers (event) {
    this.element.querySelectorAll('[data-bs-toggle="dropdown"][aria-expanded="true"]').forEach((toggle) => {
      if (toggle !== event.target) bootstrap.Dropdown.getOrCreateInstance(toggle).hide()
    })
  }

  toggleCollapsed () {
    const collapsed = !document.documentElement.classList.contains('sidebar-collapsed')
    this.applyCollapsed(collapsed)
    try {
      localStorage.setItem(STORAGE_KEY, collapsed ? '1' : '0')
    } catch (e) {}
  }

  applyCollapsed (collapsed) {
    document.documentElement.classList.toggle('sidebar-collapsed', collapsed)
    if (!this.hasToggleTarget) return

    const label = collapsed ? 'Espandi menu' : 'Riduci menu'
    this.toggleTarget.setAttribute('aria-pressed', collapsed)
    this.toggleTarget.setAttribute('aria-label', label)
    this.toggleTarget.title = label
  }

  storedCollapsed () {
    try {
      return localStorage.getItem(STORAGE_KEY) === '1'
    } catch (e) {
      return false
    }
  }
}
