import { Controller } from "@hotwired/stimulus"
import { crypt, decrypt } from 'libs/crypter'

export default class extends Controller {
  static targets = [
    'input',
    'copyPassword'
  ]

  static values = {
    phrase: { type: String, default: '' }
  }

  connect() {
    if (!this.loadCryptPassword()) {
      this.actionInstance = this.application.getControllerForElementAndIdentifier(document.getElementById('action-controller'), 'action')
      setTimeout(() => this.actionInstance?.closeModal(), 500)
      return
    }

    this.inputTargets.forEach((target) => {
      target.value = decrypt(target.dataset.value, this.cryptPassword)
      if (target.name != 'password') return
      if (target.value.length < 1) return
      if (!this.hasCopyPasswordTarget) return

      // copy target value to clipboard
      navigator.clipboard.writeText(target.value)
      this.copyPasswordTarget.classList.remove('d-none')

      setTimeout(() => {
        this.copyPasswordTarget.classList.add('d-none')
      }, 2500)
    })
  }

  loadCryptPassword() {
    // load crypt password
    let cryptPassword = localStorage.getItem('credentials_password')
    if (!cryptPassword) {
      cryptPassword = prompt('Inserisci la password di criptazione')
    }

    // validate crypt password
    const decryptedPhrase = decrypt(this.phraseValue, cryptPassword)
    if (decryptedPhrase != 'Matilda') {
      alert('Password non valida')
      return false
    }

    // save crypt password
    localStorage.setItem('credentials_password', cryptPassword)
    this.cryptPassword = cryptPassword

    return true
  }
}
