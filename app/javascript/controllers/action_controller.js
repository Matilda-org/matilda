import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
    this.modalDOM = document.getElementById('actionModal')
    this.modal = bootstrap.Modal.getOrCreateInstance(this.modalDOM)

    if (this.detectActionInsideModalDOM()) {
      this.modal.show()
      this.focusFirstField()
    }
  }

  // Sposta il focus sul primo campo del contenuto caricato in async nella modale.
  // Bootstrap intrappola e ripristina già il focus, ma non lo porta sul contenuto
  // del turbo frame quando arriva.
  focusFirstField() {
    const selector = 'input:not([type=hidden]):not([disabled]):not([data-skip-autofocus]), select:not([disabled]):not([data-skip-autofocus]), textarea:not([disabled]):not([data-skip-autofocus]), trix-editor:not([data-skip-autofocus])'
    // Only autofocus real form fields. No fallback to arbitrary links/buttons:
    // focusing a content link (e.g. the project tag) would fire its tooltip on focus.
    const target = this.modalDOM.querySelector(selector)
    if (!target) return

    if (this.modalDOM.classList.contains('show')) {
      target.focus()
    } else {
      this.modalDOM.addEventListener('shown.bs.modal', () => target.focus(), { once: true })
    }
  }

  closeModal(e) {
    if (e?.currentTarget?.getAttribute('data-turbo-frame') == '_top') {
      this.modal.hide()
      Turbo.visit(window.location.href, { action: "replace" })
      e.preventDefault()
    } else {
      this.modal.hide()
      setTimeout(() => {
        const action = this.modalDOM.querySelector('#action')
        if (!action) return

        action.src = null
        action.innerHTML = ''
      }, 250)
    }
  }

  detectActionInsideModalDOM() {
    let result = false
    let counter = 0
    let parent = this.element.parentElement

    while (!result && counter < 10 && parent) {
      result = parent == this.modalDOM
      parent = parent.parentElement
      counter++
    }

    return result
  }
}
