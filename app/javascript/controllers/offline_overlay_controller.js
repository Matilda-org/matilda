import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [
    'overlay',
    'status'
  ]

  connect() {
    this.isVisible = false
    this.enterFrame = null
    this.update = this.update.bind(this)
    this.onTransitionEnd = this.onTransitionEnd.bind(this)

    window.addEventListener('online', this.update)
    window.addEventListener('offline', this.update)
    this.overlayTarget.addEventListener('transitionend', this.onTransitionEnd)

    this.update()
  }

  disconnect() {
    window.removeEventListener('online', this.update)
    window.removeEventListener('offline', this.update)
    this.overlayTarget.removeEventListener('transitionend', this.onTransitionEnd)
    if (this.enterFrame) {
      window.cancelAnimationFrame(this.enterFrame)
      this.enterFrame = null
    }
  }

  update() {
    this.setOffline(!navigator.onLine)
  }

  setOffline(isOffline) {
    this.isVisible = isOffline
    this.overlayTarget.hidden = false
    this.overlayTarget.setAttribute('aria-hidden', String(!isOffline))
    this.statusTarget.textContent = 'Controlla la connessione e riprova.'
    document.body?.classList.toggle('overflow-hidden', isOffline)

    if (this.enterFrame) {
      window.cancelAnimationFrame(this.enterFrame)
      this.enterFrame = null
    }

    if (isOffline) {
      this.overlayTarget.classList.remove('is-visible')
      this.enterFrame = window.requestAnimationFrame(() => {
        this.overlayTarget.classList.add('is-visible')
        this.enterFrame = null
      })
      return
    }

    this.overlayTarget.classList.remove('is-visible')
  }

  onTransitionEnd(event) {
    if (event.target !== this.overlayTarget || event.propertyName !== 'opacity') return
    if (this.isVisible) return

    this.overlayTarget.hidden = true
  }
}
