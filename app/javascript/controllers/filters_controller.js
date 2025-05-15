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

    this.element.addEventListener('turbo:submit-start', this.beforeSubmit.bind(this))
    this.element.addEventListener('turbo:submit-end', this.afterSubmit.bind(this))
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
