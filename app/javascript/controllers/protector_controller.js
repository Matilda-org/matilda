import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [
    'content'
  ]

  connect() {
    // do nothing on mobile
    this.isMobile = window.matchMedia('(max-width: 768px)').matches
    if (this.isMobile) return

    this.showOriginalContentBind = this.showOriginalContent.bind(this)
    this.hideOriginalContentBind = this.hideOriginalContent.bind(this)

    this.element.addEventListener('mouseenter', this.showOriginalContentBind)
    this.element.addEventListener('mouseleave', this.hideOriginalContentBind)

    // affordance: signal "hidden content, hover to reveal" (not a loading state)
    this.hint = document.createElement('i')
    this.hint.className = 'bi bi-eye-slash protector__hint'
    this.hint.setAttribute('aria-hidden', 'true')
    this.element.appendChild(this.hint)

    this.hideOriginalContent()
  }

  disconnect() {
    this.element.removeEventListener('mouseenter', this.showOriginalContentBind)
    this.element.removeEventListener('mouseleave', this.hideOriginalContentBind)

    if (this.hint) this.hint.remove()
    this.showOriginalContent()
  }

  showOriginalContent() {
    this.element.classList.remove('protector--masked')
    this.contentTarget.style.opacity = 1
  }

  hideOriginalContent() {
    this.element.classList.add('protector--masked')
    this.contentTarget.style.opacity = 1
  }
}
