import { Controller } from '@hotwired/stimulus'

// Shows a Bootstrap toast as soon as it is rendered and removes it once hidden,
// so Turbo never caches (and replays) an already seen message.
export default class extends Controller {
  connect () {
    this.element.addEventListener('hidden.bs.toast', () => this.element.remove(), { once: true })
    bootstrap.Toast.getOrCreateInstance(this.element, { delay: 4000 }).show()
  }
}
