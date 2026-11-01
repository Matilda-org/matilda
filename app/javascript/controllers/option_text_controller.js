import { Controller } from '@hotwired/stimulus'

// Copies the label of the chosen option into another field (eg. attachment
// typology → title), so the user starts from a sensible default.
export default class extends Controller {
  static targets = ['select', 'output']

  copy () {
    const option = this.selectTarget.selectedOptions[0]
    this.outputTarget.value = this.selectTarget.value === '' ? '' : option.text
  }
}
