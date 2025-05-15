import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ['submit']

  connect() {
    
  }

  update(e) {
    const value = e.target.value
    if (value.toLowerCase() === 'elimina') {
      this.submitTarget.disabled = false
    } else {
      this.submitTarget.disabled = true
    }
  }
}
