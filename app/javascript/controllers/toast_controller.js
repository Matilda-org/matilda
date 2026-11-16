import { Controller } from '@hotwired/stimulus'

// Shows a Bootstrap toast as soon as it is rendered and removes it once hidden,
// so Turbo never caches (and replays) an already seen message.
// Longer messages stay longer; Bootstrap already pauses the timer on hover/focus.
export default class extends Controller {
  connect () {
    const delay = Math.min(10000, Math.max(4000, this.element.textContent.trim().length * 70))

    this.element.addEventListener('hidden.bs.toast', () => this.element.remove(), { once: true })
    bootstrap.Toast.getOrCreateInstance(this.element, { delay }).show()
  }
}
