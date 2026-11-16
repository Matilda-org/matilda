import { Controller } from '@hotwired/stimulus'

const STORAGE_KEY = 'sidebar-collapsed'
// Matches the width transition in components/_nav-section.scss
const ANIMATION_MS = 250

// Sidebar submenus use data-bs-auto-close="false" so they stay open while
// browsing them: opening one closes the others by hand, one section at a time.
// The sidebar can also shrink to an icon-only rail; the choice is remembered
// per browser and lives on <html>, which Turbo keeps across visits.
export default class extends Controller {
  static targets = ['toggle', 'toggleLabel']

  connect () {
    this.applyCollapsed(this.storedCollapsed())
  }

  disconnect () {
    clearTimeout(this.animationTimer)
  }

  closeOthers (event) {
    this.element.querySelectorAll('[data-bs-toggle="dropdown"][aria-expanded="true"]').forEach((toggle) => {
      if (toggle !== event.target) bootstrap.Dropdown.getOrCreateInstance(toggle).hide()
    })
  }

  toggleCollapsed () {
    const collapsed = !document.documentElement.classList.contains('sidebar-collapsed')

    // Animate only on a user toggle, never when a page loads already collapsed
    const root = document.documentElement
    root.classList.add('sidebar-animating')
    clearTimeout(this.animationTimer)
    this.animationTimer = setTimeout(() => root.classList.remove('sidebar-animating'), ANIMATION_MS)

    this.applyCollapsed(collapsed)
    try {
      localStorage.setItem(STORAGE_KEY, collapsed ? '1' : '0')
    } catch (e) {}
  }

  applyCollapsed (collapsed) {
    document.documentElement.classList.toggle('sidebar-collapsed', collapsed)

    // Icon-only links show their name on hover; with visible labels a tooltip would repeat them
    this.element.querySelectorAll('.nav-link').forEach((link) => {
      const label = link.querySelector('span')?.textContent.trim()
      if (collapsed && label) {
        link.title = label
      } else {
        link.removeAttribute('title')
      }
    })

    if (!this.hasToggleTarget) return

    const label = collapsed ? 'Espandi menu' : 'Riduci menu'
    this.toggleTarget.setAttribute('aria-expanded', !collapsed)
    if (collapsed) {
      this.toggleTarget.title = label
    } else {
      this.toggleTarget.removeAttribute('title')
    }
    if (this.hasToggleLabelTarget) this.toggleLabelTarget.textContent = label
  }

  storedCollapsed () {
    try {
      return localStorage.getItem(STORAGE_KEY) === '1'
    } catch (e) {
      return false
    }
  }
}
