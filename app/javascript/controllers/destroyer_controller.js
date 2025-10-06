import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ['submit']

  connect() {
    
  }

  update(e) {
    const value = e.target.value.toLowerCase()
    // Supporta sia "elimina" che "rigenera"
    if (value === 'elimina' || value === 'rigenera') {
      this.submitTarget.disabled = false
    } else {
      this.submitTarget.disabled = true
    }
  }
}
