import { Controller } from "@hotwired/stimulus"
import { debounce } from 'libs/utils'

export default class extends Controller {
  static targets = [
    'buttonClear',
    'inputToClear',
    'submit'
  ]

  connect() {
    this._submitDebounced = debounce(this.submit.bind(this), 500)
    this.beforeSubmit = this.beforeSubmit.bind(this)
    this.afterSubmit = this.afterSubmit.bind(this)

    this.element.addEventListener('turbo:submit-start', this.beforeSubmit)
    this.element.addEventListener('turbo:submit-end', this.afterSubmit)
  }

  disconnect() {
    this.element.removeEventListener('turbo:submit-start', this.beforeSubmit)
    this.element.removeEventListener('turbo:submit-end', this.afterSubmit)
  }

  submitDebounced(e) {
    this._submitDebounced()
  }

  beforeSubmit(e) {
    if (this.hasSubmitTarget) {
      this.submitTarget.disabled = true
      this._originalSubmitText = this.submitTarget.innerHTML
      this.submitTarget.innerHTML = '<i class="bi bi-hourglass-split"></i>'
    }
  }

  afterSubmit(e) {
    if (this.hasSubmitTarget) {
      this.submitTarget.disabled = false
      this.submitTarget.innerHTML = this._originalSubmitText
    }

    // Riporto sull'url della pagina attuale i parametri del form
    const url = new URL(window.location)
    const formData = new FormData(this.element)

    for (const [key, value] of formData.entries()) {
      if (value && value.length > 0) {
        url.searchParams.set(key, value)
      } else {
        url.searchParams.delete(key)
      }
    }
    // New filters restart from the first page: a stale page could be empty
    url.searchParams.delete('page')

    // Keep Turbo's restoration state, so Back and scroll restoration still work
    window.history.replaceState(window.history.state, '', url)
  }

  submit() {
    this.element.requestSubmit()
  }

  clear(e) {
    this.inputToClearTargets.forEach((input) => {
      input.value = ''
    })
    this.submit()
  }
}
