import { Controller } from '@hotwired/stimulus'
import { decrypt } from 'libs/crypter'
import { storedCryptPassword, unlockCryptPassword } from 'libs/crypt_password'

export default class extends Controller {
  static targets = [
    'content',
    'input',
    'unlock',
    'unlockPassword',
    'unlockError',
    'password',
    'passwordToggle',
    'copyNotice'
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
    this.inputTargets.forEach((target) => {
      target.value = decrypt(target.dataset.value, cryptPassword)
    })
    this.contentTarget.hidden = false
    this.copyPassword()
  }

  // Opening a credential is mostly about its password: copy it right away
  copyPassword () {
    const password = this.hasPasswordTarget ? this.passwordTarget.value : ''
    if (!password || !navigator.clipboard) return

    navigator.clipboard.writeText(password).then(() => {
      if (!this.hasCopyNoticeTarget) return

      this.copyNoticeTarget.textContent = 'Password copiata negli appunti.'
      clearTimeout(this.copyNoticeTimer)
      this.copyNoticeTimer = setTimeout(() => { this.copyNoticeTarget.textContent = '' }, 2500)
    }).catch(() => {})
  }

  disconnect () {
    clearTimeout(this.copyNoticeTimer)
  }

  togglePassword () {
    const visible = this.passwordTarget.type === 'password'
    this.passwordTarget.type = visible ? 'text' : 'password'
    this.passwordToggleTarget.setAttribute('aria-label', visible ? 'Nascondi password' : 'Mostra password')
    this.passwordToggleTarget.setAttribute('aria-pressed', visible)
    this.passwordToggleTarget.querySelector('i').className = visible ? 'bi bi-eye-slash' : 'bi bi-eye'
  }
}
