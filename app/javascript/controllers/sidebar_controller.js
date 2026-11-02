import { Controller } from '@hotwired/stimulus'

// Sidebar submenus use data-bs-auto-close="false" so they stay open while
// browsing them: opening one closes the others by hand, one section at a time.
export default class extends Controller {
  closeOthers (event) {
    this.element.querySelectorAll('[data-bs-toggle="dropdown"][aria-expanded="true"]').forEach((toggle) => {
      if (toggle !== event.target) bootstrap.Dropdown.getOrCreateInstance(toggle).hide()
    })
  }
}
