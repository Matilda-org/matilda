import { Controller } from '@hotwired/stimulus'

// Navbar search: Ctrl/⌘+K focuses it from anywhere, results open in the dashboard search module.
export default class extends Controller {
  static targets = ['input', 'hint']

  connect () {
    if (this.hasHintTarget && /Mac|iPhone|iPad/.test(navigator.platform)) this.hintTarget.textContent = '⌘ K'
  }

  focus (event) {
    if (event.key?.toLowerCase() !== 'k' || !(event.metaKey || event.ctrlKey)) return

    event.preventDefault()
    this.inputTarget.focus()
    this.inputTarget.select()
  }
}
