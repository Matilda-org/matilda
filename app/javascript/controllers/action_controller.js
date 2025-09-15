import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
    this.modalDOM = document.getElementById('actionModal')
    this.modal = bootstrap.Modal.getOrCreateInstance(this.modalDOM)

    if (this.detectActionInsideModalDOM()) {
      this.modal.show()
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
