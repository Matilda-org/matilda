import { Controller } from '@hotwired/stimulus'

/**
 * Searchable checkbox list: filters options by their data-search text, selects
 * all visible ones and keeps a live "N selezionati" counter. The submit button
 * stays disabled until at least one option is checked.
 */
export default class extends Controller {
  static targets = ['filter', 'option', 'checkbox', 'counter', 'empty', 'submit']

  connect () {
    this.update()
  }

  filter () {
    const query = this.filterTarget.value.trim().toLowerCase()
    let visible = 0
    this.optionTargets.forEach((option) => {
      const match = option.dataset.search.includes(query)
      option.hidden = !match
      if (match) visible++
    })
    if (this.hasEmptyTarget) this.emptyTarget.hidden = visible > 0
  }

  selectVisible () {
    this.optionTargets
      .filter((option) => !option.hidden)
      .forEach((option) => { option.querySelector('input[type="checkbox"]').checked = true })
    this.update()
  }

  update () {
    const count = this.checkboxTargets.filter((checkbox) => checkbox.checked).length
    this.counterTarget.textContent = `${count} ${count === 1 ? 'selezionato' : 'selezionati'}`
    if (this.hasSubmitTarget) this.submitTarget.disabled = count === 0
  }
}
