import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [
    'content',
    'background',
    'chat',
    'submit',
    'textarea'
  ]

  connect() {
  
  }

  chatTargetConnected() {
    // scroll down to the bottom of the chat
    this.chatTarget.scrollTop = this.chatTarget.scrollHeight
  }

  textareaTargetConnected() {
    // setup listener on enter key if textarea is focused
    this.textareaTarget.addEventListener('focus', (e) => {
      this._textareaFocused = true
    })
    this.textareaTarget.addEventListener('blur', (e) => {
      this._textareaFocused = false
    })
    this.textareaTarget.addEventListener('keydown', (e) => {
      if (e.keyCode == 13 && !e.shiftKey) {
        e.preventDefault()
        this.submitTarget.click()
      }
    })
  }

  textareaTargetDisconnected() {
    this._textareaFocused = false
  }

  open(e) {
    e.preventDefault()

    this.contentTarget.classList.add('is-open')
    this.backgroundTarget.classList.add('is-open')
  }

  close(e) {
    e.preventDefault()

    this.contentTarget.classList.remove('is-open')
    this.backgroundTarget.classList.remove('is-open')
  }

}