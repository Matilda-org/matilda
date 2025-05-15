import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
    this.tooltip = new bootstrap.Tooltip(this.element, {
      title: this.element.dataset.tooltip,
      html: true,
    })
  }

  disconnect() {
    this.tooltip.dispose()
  }
}