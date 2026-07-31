import { Controller } from '@hotwired/stimulus'

/**
 * auto-submit
 *
 * Submits the form as soon as one of its fields changes, so inline edits
 * (like the tracking day in the tracking list) need no submit button.
 */
export default class extends Controller {
  submit () {
    this.element.requestSubmit()
  }
}
