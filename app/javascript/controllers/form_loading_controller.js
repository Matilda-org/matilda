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
 * When the fetch request is completed, the submit button is enabled again and the loading spinner is removed.
 */
export default class extends Controller {
  static targets = [
    'submit'
  ]

  connect() {
    this.beforeFetchRequest = this.beforeFetchRequest.bind(this)
    this.beforeFetchResponse = this.beforeFetchResponse.bind(this)
    this.element.addEventListener('turbo:before-fetch-request', this.beforeFetchRequest)
    this.element.addEventListener('turbo:before-fetch-response', this.beforeFetchResponse)
  }

  disconnect() {
    this.element.removeEventListener('turbo:before-fetch-request', this.beforeFetchRequest)
    this.element.removeEventListener('turbo:before-fetch-response', this.beforeFetchResponse)
  }

  beforeFetchRequest() {
    this.submitTarget.disabled = true
    this.submitTarget.insertAdjacentHTML('beforeend', '<span class="spinner-border spinner-border-sm ms-2" role="status" aria-hidden="true"></span>')
  }

  beforeFetchResponse() {
    this.submitTarget.disabled = false
    this.submitTarget.querySelector('.spinner-border').remove()
  }
}