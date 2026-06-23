import { Controller } from '@hotwired/stimulus'

/**
 * manual-track
 *
 * Handles the quick-duration buttons in the "add manual time" task form.
 * Clicking a button selects its duration (in seconds), highlights it, writes
 * the value into the hidden `duration` field and enables the submit button.
 */
export default class extends Controller {
  static targets = ['duration', 'button', 'submit']

  select(e) {
    const button = e.currentTarget

    this.buttonTargets.forEach((b) => b.classList.toggle('active', b === button))
    this.durationTarget.value = button.dataset.seconds

    if (this.hasSubmitTarget) this.submitTarget.disabled = false
  }
}
