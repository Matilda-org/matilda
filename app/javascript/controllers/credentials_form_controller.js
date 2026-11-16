import { Controller } from '@hotwired/stimulus'
import { crypt, decrypt } from 'libs/crypter'
import { storedCryptPassword, unlockCryptPassword } from 'libs/crypt_password'

export default class extends Controller {
  static targets = [
    'fields',
    'submit',
    'unlock',
    'unlockPassword',
    'unlockError',
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

  connect () {
    const cryptPassword = storedCryptPassword(this.phraseValue)
    if (cryptPassword) {
      this.reveal(cryptPassword)
    } else {
      this.unlockTarget.hidden = false
      this.unlockPasswordTarget.focus()
    }
  }

  unlock (e) {
    e.preventDefault()

    const cryptPassword = unlockCryptPassword(this.phraseValue, this.unlockPasswordTarget.value)
    if (!cryptPassword) {
      this.unlockErrorTarget.textContent = 'Password non valida, riprova.'
      this.unlockPasswordTarget.setAttribute('aria-invalid', 'true')
      this.unlockPasswordTarget.select()
      return
    }

    this.unlockTarget.hidden = true
    this.unlockPasswordTarget.value = ''
    this.reveal(cryptPassword)
  }

  reveal (cryptPassword) {
    this.cryptPassword = cryptPassword
    this.usernameTarget.value = decrypt(this.secureUsernameTarget.value, cryptPassword)
    this.passwordTarget.value = decrypt(this.securePasswordTarget.value, cryptPassword)
    this.contentTarget.value = decrypt(this.secureContentTarget.value, cryptPassword)
    this.fieldsTarget.hidden = false
    this.submitTarget.disabled = false
  }

  onSubmit (e) {
    // never send plain values, nor values encrypted without the password
    if (!this.cryptPassword) {
      e.preventDefault()
      return
    }

    this.secureUsernameTarget.value = crypt(this.usernameTarget.value, this.cryptPassword)
    this.securePasswordTarget.value = crypt(this.passwordTarget.value, this.cryptPassword)
    this.secureContentTarget.value = crypt(this.contentTarget.value, this.cryptPassword)

    this.usernameTarget.setAttribute('disabled', true)
    this.passwordTarget.setAttribute('disabled', true)
    this.contentTarget.setAttribute('disabled', true)
  }
}
