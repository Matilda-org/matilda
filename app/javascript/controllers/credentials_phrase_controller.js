import { Controller } from "@hotwired/stimulus"
import { crypt } from 'libs/crypter'

export default class extends Controller {
  static targets = [
    'submit',
    'password',
    'passwordConfirmation',
    'phrase'
  ]

  connect() {
    this.modal = bootstrap.Modal.getOrCreateInstance(this.element)
    this.modal.show()
  }

  onSubmit(e) {
    this.passwordTarget.setAttribute('disabled', true)
    this.passwordConfirmationTarget.setAttribute('disabled', true)
    this.phraseTarget.value = crypt('Matilda', this.passwordTarget.value)
    this.modal.hide()
  }

  onChangePassword(e) {
    const password = this.passwordTarget.value
    const passwordConfirmation = this.passwordConfirmationTarget.value
    if (!password || !passwordConfirmation || password != passwordConfirmation) {
      this.submitTarget.setAttribute('disabled', true)
    } else {
      this.submitTarget.removeAttribute('disabled')
    }
  }
}
