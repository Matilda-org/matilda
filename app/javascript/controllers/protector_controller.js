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

    this.hideOriginalContent()
  }

  disconnect() {
    this.element.removeEventListener('mouseenter', this.showOriginalContentBind)
    this.element.removeEventListener('mouseleave', this.hideOriginalContentBind)

    this.showOriginalContent()
  }

  showOriginalContent() {
    // remove placeholder
    if (this.placeholder) this.placeholder.remove()

    // show original content
    this.contentTarget.style.opacity = 1
  }

  hideOriginalContent() {
    if (!this.element.classList.contains('position-relative')) this.element.classList.add('position-relative')
    if (!this.element.classList.contains('overflow-hidden')) this.element.classList.add('overflow-hidden')
    const numberOfLines = this.getNumberOfLines()

    // remove old placeholder
    const oldPlaceholder = this.element.querySelector('.protector-placeholder')
    if (oldPlaceholder) oldPlaceholder.remove()

    // create placeholder
    if (this.placeholder) this.placeholder.remove()
    this.placeholder = document.createElement('div')
    this.placeholder.classList.add('protector-placeholder')
    this.placeholder.classList.add('position-absolute', 'top-0', 'start-0', 'w-100', 'h-100', 'd-flex', 'flex-column', 'justify-content-center', 'align-items-stretch')
    for (let i = 0; i < numberOfLines; i++) {
      const line = document.createElement('div')
      line.classList.add('placeholder', 'w-100', 'mb-1', 'mt-1')
      line.style.cursor = 'initial'
      this.placeholder.appendChild(line)
    }
    this.element.appendChild(this.placeholder)

    // hide original content
    this.contentTarget.style.opacity = 0
  }

  getNumberOfLines() {
    const contentHeight = this.element.offsetHeight
    const contentFontSize = parseFloat(window.getComputedStyle(this.contentTarget).fontSize.replace('px', ''))
    const contentLineHeight = parseFloat(window.getComputedStyle(this.contentTarget).lineHeight.replace('px', ''))

    const lineHeight = contentLineHeight / contentFontSize
    const numberOfLines = contentHeight / contentFontSize / lineHeight

    const finalNumberOfLines = Math.ceil(numberOfLines) 
    return finalNumberOfLines || 1
  }
}