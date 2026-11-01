import { Controller } from '@hotwired/stimulus'

const STORAGE_PREFIX = 'page-card:'

// On mobile the page cards are collapsible; each card remembers whether it was
// left open (per page and title), so users don't reopen the same sections at
// every visit. On desktop they are always open.
export default class extends Controller {
  static targets = [
    'header',
    'content'
  ]

  static values = { key: String }

  connect() {
    this.isMobile = window.matchMedia('(max-width: 768px)').matches
    this.headerTarget.disabled = !this.isMobile || this.contentTarget.hasAttribute('always-open')
    this.setExpanded(!this.contentTarget.hasAttribute('closed'))

    if (!this.isMobile) return
    if (this.contentTarget.hasAttribute('always-open')) return

    if (this.storedOpen()) {
      this.open()
    } else {
      this.close(true)
    }

    this.contentObserver = new MutationObserver(() => this.manageContentChange())
    this.contentObserver.observe(this.contentTarget, { childList: true, subtree: true })
  }

  disconnect() {
    this.contentObserver?.disconnect()
  }

  manageHeaderClick(e = null) {
    if (e) e.preventDefault()
    if (!this.isMobile) return
    if (this.contentTarget.hasAttribute('always-open')) return

    if (this.contentTarget.hasAttribute('closed')) {
      this.open()
      this.storeOpen(true)
    } else {
      this.close()
      this.storeOpen(false)
    }
  }

  manageContentChange(e = null) {
    if (e) e.preventDefault()
    if (this.contentTarget.hasAttribute('closed')) return

    setTimeout(() => {
      this.contentTarget.style.height = `${this.getHeight()}px`
    }, 100)
  }

  open() {
    this.contentTarget.classList.remove('d-none')

    const height = this.getHeight()
    this.contentTarget.style.height = `${height}px`
    this.contentTarget.removeAttribute('closed')
    this.headerTarget.classList.remove('rounded-bottom')
    this.setExpanded(true)
  }

  close(firstClose = false) {
    if (firstClose) this.contentTarget.classList.add('d-none')

    this.contentTarget.style.height = '0px'
    this.contentTarget.setAttribute('closed', true)
    this.setExpanded(false)

    setTimeout(() => {
      this.headerTarget.classList.add('rounded-bottom')
    }, firstClose ? 0 : 300)
  }

  setExpanded(expanded) {
    this.headerTarget.setAttribute('aria-expanded', expanded ? 'true' : 'false')
  }

  getHeight() {
    const cardBody = this.contentTarget.querySelector('.card-body')
    const cardFooter = this.contentTarget.querySelector('.card-footer')
    return (cardBody?.offsetHeight || 0) + (cardFooter?.offsetHeight || 0)
  }

  // Storage can be unavailable (private mode, blocked site data): the card
  // simply falls back to closed.
  storedOpen() {
    try {
      return window.localStorage.getItem(this.storageKey) === 'open'
    } catch {
      return false
    }
  }

  storeOpen(open) {
    try {
      if (open) {
        window.localStorage.setItem(this.storageKey, 'open')
      } else {
        window.localStorage.removeItem(this.storageKey)
      }
    } catch {}
  }

  get storageKey() {
    return `${STORAGE_PREFIX}${window.location.pathname}:${this.keyValue}`
  }
}
