import { Controller } from '@hotwired/stimulus'

export default class extends Controller {
  static targets = [
    'header',
    'content'
  ]

  connect() {
    this.isMobile = window.matchMedia('(max-width: 768px)').matches
    if (!this.isMobile) return
    if (this.contentTarget.hasAttribute('always-open')) return
    
    this.close(true)
    this.headerTarget.addEventListener('click', this.manageHeaderClick.bind(this))

    this.contentObserver = new MutationObserver(() => this.manageContentChange())
    this.contentObserver.observe(this.contentTarget, { childList: true, subtree: true })
  }

  disconnect() {
    if (!this.isMobile) return
    if (this.contentTarget.hasAttribute('always-open')) return

    this.headerTarget.removeEventListener('click', this.manageHeaderClick.bind(this))
    this.contentObserver.disconnect()
  }

  manageHeaderClick(e = null) {
    if (e) e.preventDefault()
    if (this.contentTarget.hasAttribute('closed')) {
      this.open()
    } else {
      this.close()
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
  }

  close(firstClose = false) {
    if (firstClose) this.contentTarget.classList.add('d-none')

    this.contentTarget.style.height = '0px'
    this.contentTarget.setAttribute('closed', true)

    setTimeout(() => {
      this.headerTarget.classList.add('rounded-bottom')
    }, firstClose ? 0 : 300)
  }

  getHeight() {
    const cardBody = this.contentTarget.querySelector('.card-body')
    const cardFooter = this.contentTarget.querySelector('.card-footer')
    return cardBody.offsetHeight + (cardFooter?.offsetHeight || 0)
  }
}