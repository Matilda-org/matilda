import { Controller } from "@hotwired/stimulus"

/**
 * This controller is used to add a loading spinner to the submit button of a form.
 * 
 * Usage:
 * Add `data-controller="form-loading"` to the form element.
 * Add `data-form-loading-target="submit"` to the submit button of the form.
 * 
 * How it works:
 * When the form is submitted, the turbo:before-fetch-request event is listened to.
 * When the event is triggered, the submit button is disabled and a loading spinner is added to it.
 * On turbo:submit-end the button is enabled again and the spinner removed. Unlike
 * turbo:before-fetch-response it also fires on network errors, so the button never stays stuck.
 */
export default class extends Controller {
  static targets = [
    'submit'
  ]

  connect() {
    this.beforeFetchRequest = this.beforeFetchRequest.bind(this)
    this.submitEnd = this.submitEnd.bind(this)
    this.element.addEventListener('turbo:before-fetch-request', this.beforeFetchRequest)
    this.element.addEventListener('turbo:submit-end', this.submitEnd)
  }

  disconnect() {
    this.element.removeEventListener('turbo:before-fetch-request', this.beforeFetchRequest)
    this.element.removeEventListener('turbo:submit-end', this.submitEnd)
  }

  beforeFetchRequest() {
    this.submitTarget.disabled = true
    if (this.submitTarget.querySelector('.spinner-border')) return

    this.submitTarget.insertAdjacentHTML('beforeend', '<span class="spinner-border spinner-border-sm ms-2" role="status" aria-hidden="true"></span>')
  }

  submitEnd() {
    this.submitTarget.disabled = false
    this.submitTarget.querySelector('.spinner-border')?.remove()
  }
}
