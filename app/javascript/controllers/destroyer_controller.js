import { Controller } from "@hotwired/stimulus"

// Enables the submit only once the user typed the confirmation word.
// Listens to `input`, so pasting and autofill count too.
export default class extends Controller {
  static targets = ['submit']
  static values = { word: { type: String, default: 'elimina' } }

  update(e) {
    this.submitTarget.disabled = e.target.value.trim().toLowerCase() !== this.wordValue.toLowerCase()
  }
}
