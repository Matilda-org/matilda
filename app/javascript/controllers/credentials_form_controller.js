import { Controller } from "@hotwired/stimulus"
import { crypt, decrypt } from 'libs/crypter'

export default class extends Controller {
  static targets = [
    'secureUsername',
    'securePassword',
    'secureContent',
    'username',
    'password',
    'content'
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

    this.usernameTarget.value = decrypt(this.secureUsernameTarget.value, this.cryptPassword)
    this.passwordTarget.value = decrypt(this.securePasswordTarget.value, this.cryptPassword)
    this.contentTarget.value = decrypt(this.secureContentTarget.value, this.cryptPassword)
  }

  onSubmit(e) {
    this.secureUsernameTarget.value = crypt(this.usernameTarget.value, this.cryptPassword)
    this.securePasswordTarget.value = crypt(this.passwordTarget.value, this.cryptPassword)
    this.secureContentTarget.value = crypt(this.contentTarget.value, this.cryptPassword)

    this.usernameTarget.setAttribute('disabled', true)
    this.passwordTarget.setAttribute('disabled', true)
    this.contentTarget.setAttribute('disabled', true)
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
