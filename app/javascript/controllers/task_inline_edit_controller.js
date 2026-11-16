import { Controller } from '@hotwired/stimulus'

// Click-to-edit field of the task detail. The value is a button that swaps to its
// input; the form saves into the field's turbo-frame, which the server re-renders
// as text (or still open, with the error, when the value is invalid).
// Text and date save on Enter or blur (date fires change on every typed digit),
// selects save on change. Esc cancels and gives focus back to the button.
export default class extends Controller {
  static targets = ['display', 'trigger', 'form', 'input']
  static values = { mode: String, editing: Boolean, focus: Boolean, original: String }

  connect () {
    // value to compare with and to restore on cancel: after a failed save the input holds the typed one
    this.pristine = this.editingValue ? this.originalValue : this.inputTarget.value

    // Only reclaim focus when the swapped frame dropped it, never steal it from elsewhere
    if (!this.focusLost()) return

    if (this.editingValue) {
      this.inputTarget.focus()
    } else if (this.focusValue) {
      this.triggerTarget.focus()
    }
  }

  edit () {
    this.displayTarget.hidden = true
    this.formTarget.hidden = false
    this.inputTarget.focus()
    if (this.modeValue === 'text') this.inputTarget.select()
  }

  keydown (event) {
    if (event.key === 'Escape') {
      // keep the surrounding modal open: Esc only leaves the field
      event.preventDefault()
      event.stopPropagation()
      this.cancel()
    } else if (event.key === 'Enter') {
      event.preventDefault()
      this.save()
    }
  }

  change () {
    if (this.modeValue === 'select') this.save()
  }

  blur () {
    if (this.submitting || this.formTarget.hidden) return

    if (this.changed()) {
      if (this.modeValue !== 'select') this.save()
    } else {
      this.close()
    }
  }

  submit () {
    this.submitting = true
  }

  save () {
    if (this.submitting) return
    if (!this.changed()) return this.cancel()

    this.formTarget.requestSubmit()
  }

  cancel () {
    this.close()
    this.triggerTarget.focus()
  }

  close () {
    this.inputTarget.value = this.pristine
    this.inputTarget.classList.remove('is-invalid')
    this.inputTarget.removeAttribute('aria-invalid')
    this.formTarget.querySelector('.invalid-feedback')?.remove()
    this.formTarget.hidden = true
    this.displayTarget.hidden = false
  }

  changed () {
    return this.inputTarget.value !== this.pristine
  }

  focusLost () {
    return !document.activeElement || document.activeElement === document.body
  }
}
