import { Controller } from "@hotwired/stimulus"

// Auto-growing comment textarea (capped via CSS max-height) with
// Cmd/Ctrl + Enter to submit while the field is focused.
export default class extends Controller {
  static targets = ["input"]

  connect() {
    if (this.hasInputTarget) this.grow()
  }

  grow() {
    const el = this.inputTarget
    el.style.height = "auto"
    el.style.height = `${el.scrollHeight}px`
  }

  keydown(event) {
    if ((event.metaKey || event.ctrlKey) && event.key === "Enter") {
      event.preventDefault()
      this.element.requestSubmit()
    }
  }
}
