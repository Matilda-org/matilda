import { Controller } from '@hotwired/stimulus'

// Every add re-renders the whole column (turbo stream response + model broadcast),
// which replaces this controller's element. Open state and draft live here, keyed
// by status id, so the new instance comes back open with the same text.
const drafts = new Map()

// Inline quick add at the bottom of a kanban column: Enter creates a task with
// the typed title and keeps the input ready for the next one, Esc closes it.
export default class extends Controller {
  static targets = ['toggle', 'form', 'input', 'details']

  static values = {
    key: String
  }

  connect () {
    const draft = drafts.get(this.keyValue)
    if (!draft) return

    this.show()
    this.inputTarget.value = draft.value
    this.updateDetailsLink()
    // Refocus only if the replaced input had focus (focus fell back to body),
    // never steal it from whatever the user is doing elsewhere
    if (!document.activeElement || document.activeElement === document.body) this.inputTarget.focus()
  }

  open () {
    drafts.set(this.keyValue, { value: '' })
    this.show()
    this.inputTarget.focus()
  }

  close () {
    drafts.delete(this.keyValue)
    this.inputTarget.value = ''
    this.formTarget.hidden = true
    this.toggleTarget.hidden = false
    this.toggleTarget.focus()
  }

  input () {
    drafts.set(this.keyValue, { value: this.inputTarget.value })
    this.updateDetailsLink()
  }

  keydown (event) {
    if (event.key !== 'Escape') return

    event.preventDefault()
    this.close()
  }

  // The full modal takes over: drop the inline draft so the title is not added twice
  details () {
    drafts.delete(this.keyValue)
  }

  // Clear the draft up front: on success the column is replaced before
  // turbo:submit-end can reach this (already detached) instance
  submitStart () {
    drafts.set(this.keyValue, { value: '' })
  }

  // Failure leaves the column in place: keep the text so it can be fixed
  submitEnd (event) {
    if (event.detail.success) return

    drafts.set(this.keyValue, { value: this.inputTarget.value })
    this.inputTarget.focus()
  }

  show () {
    this.toggleTarget.hidden = true
    this.formTarget.hidden = false
  }

  updateDetailsLink () {
    const url = new URL(this.detailsTarget.href)
    const title = this.inputTarget.value.trim()
    if (title) {
      url.searchParams.set('title', title)
    } else {
      url.searchParams.delete('title')
    }
    this.detailsTarget.href = url.toString()
  }
}
