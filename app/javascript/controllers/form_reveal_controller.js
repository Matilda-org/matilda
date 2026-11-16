import { Controller } from '@hotwired/stimulus'

/**
 * Opens the collapsed section holding an invalid field, so native validation
 * can focus it instead of silently blocking the submit.
 *
 * Usage: data-controller="form-reveal" data-action="invalid->form-reveal#reveal:capture"
 * on the form (`invalid` does not bubble, hence the capture phase).
 */
export default class extends Controller {
  reveal ({ target }) {
    // every invalid field fires: only the first one is the field the browser reports
    if (this.revealing) return
    this.revealing = true
    setTimeout(() => { this.revealing = false })

    const collapse = target.closest('.collapse:not(.show)')
    if (!collapse) return

    collapse.addEventListener('shown.bs.collapse', () => {
      target.focus()
      target.reportValidity()
    }, { once: true })
    bootstrap.Collapse.getOrCreateInstance(collapse, { toggle: false }).show()
  }
}
