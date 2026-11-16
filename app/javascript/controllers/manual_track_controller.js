import { Controller } from '@hotwired/stimulus'

/**
 * manual-track
 *
 * Handles the duration picker in the "add manual time" task form.
 * Clicking a preset button writes its duration (in seconds) into the hidden
 * `duration` field; the "Personalizzato" button writes `custom` and reveals the
 * hours/minutes inputs, which the server reads instead. Either choice
 * highlights the button and enables the submit button.
 */
export default class extends Controller {
  static targets = ['duration', 'button', 'submit', 'custom', 'hours']

  select (e) {
    const button = e.currentTarget
    const custom = button.dataset.seconds === 'custom'

    this.buttonTargets.forEach((b) => b.classList.toggle('active', b === button))
    this.durationTarget.value = button.dataset.seconds

    if (this.hasCustomTarget) {
      this.customTarget.hidden = !custom
      if (custom && this.hasHoursTarget) this.hoursTarget.focus()
    }

    if (this.hasSubmitTarget) this.submitTarget.disabled = false
  }
}
