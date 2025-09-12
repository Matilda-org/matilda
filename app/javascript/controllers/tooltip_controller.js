import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
    // ignore initialization if device is touch-capable
    if ('ontouchstart' in window || navigator.maxTouchPoints) {
      return
    }

    this.tooltip = new bootstrap.Tooltip(this.element, {
      title: this.element.dataset.tooltip,
      html: true,
    })
  }

  disconnect() {
    if(this.tooltip) this.tooltip.dispose()
  }
}