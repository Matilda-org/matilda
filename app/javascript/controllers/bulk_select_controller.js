import { Controller } from '@hotwired/stimulus'

// Selection mode of shared/page-index: cards get a checkbox, a click on a card
// toggles it instead of navigating, and a sticky bar runs bulk actions on the
// checked ids. Selection lives in the page-index frame, so a filter/page reload
// clears it (the mode stays on).
export default class extends Controller {
  static targets = ['toggle', 'toggleLabel', 'bar', 'count', 'checkbox', 'status']
  static values = { path: String }

  connect () {
    this.selecting = false
    this.lastCount = 0
    this.onClick = this.onClick.bind(this)
    this.onKeydown = this.onKeydown.bind(this)
    this.onSubmitEnd = this.onSubmitEnd.bind(this)

    // Capture phase: runs before the card links (and Turbo) see the click
    this.element.addEventListener('click', this.onClick, true)
    document.addEventListener('keydown', this.onKeydown)
    // Undo and the move modal live in the action frame, outside this element
    document.addEventListener('turbo:submit-end', this.onSubmitEnd)
  }

  disconnect () {
    this.element.removeEventListener('click', this.onClick, true)
    document.removeEventListener('keydown', this.onKeydown)
    document.removeEventListener('turbo:submit-end', this.onSubmitEnd)
  }

  toggleMode () {
    this.selecting ? this.exitMode() : this.enterMode()
  }

  enterMode () {
    this.setMode(true)
    this.announce('Selezione attiva: clicca le schede da selezionare, Esc per uscire')
  }

  exitMode () {
    if (!this.selecting) return

    this.checkboxTargets.forEach((checkbox) => { checkbox.checked = false })
    this.setMode(false)
    this.update()
    this.announce('Selezione chiusa')
  }

  setMode (selecting) {
    this.selecting = selecting
    this.element.classList.toggle('c-bulk-select--active', selecting)
    if (this.hasToggleTarget) {
      this.toggleTarget.setAttribute('aria-pressed', selecting)
      this.toggleTarget.classList.toggle('active', selecting)
    }
    if (this.hasToggleLabelTarget) this.toggleLabelTarget.textContent = selecting ? 'Annulla' : 'Seleziona'
  }

  onClick (event) {
    if (!this.selecting) return

    const item = event.target.closest('.c-bulk-select__item')
    if (!item || !this.element.contains(item)) return

    const checkbox = item.querySelector('.c-bulk-select__check')
    if (event.target === checkbox) return

    event.preventDefault()
    event.stopPropagation()
    checkbox.checked = !checkbox.checked
    this.update()
  }

  onKeydown (event) {
    if (event.key !== 'Escape' || !this.selecting) return
    // Esc inside an open modal belongs to the modal
    if (document.querySelector('.modal.show')) return

    this.exitMode()
    if (this.hasToggleTarget) this.toggleTarget.focus()
  }

  selectAll () {
    this.checkboxTargets.forEach((checkbox) => { checkbox.checked = true })
    this.update()
  }

  clearSelection () {
    this.checkboxTargets.forEach((checkbox) => { checkbox.checked = false })
    this.update()
    if (this.hasToggleTarget) this.toggleTarget.focus()
  }

  update () {
    const count = this.selectedIds().length
    if (this.hasBarTarget) this.barTarget.hidden = count === 0
    if (this.hasCountTarget) this.countTarget.textContent = this.countLabel(count)
    if (count !== this.lastCount) this.announce(this.countLabel(count))
    this.lastCount = count
  }

  // The frame came back (filters, pagination, refresh after an action):
  // the new cards are unchecked, so the old selection is gone
  frameLoaded () {
    const hadSelection = this.lastCount > 0
    this.lastCount = 0
    this.update()
    if (hadSelection) this.announce('Selezione azzerata')
  }

  // Bar forms carry the checked ids as hidden inputs, added at submit time
  fillIds (event) {
    const form = event.target
    form.querySelectorAll('input[name="ids[]"]').forEach((input) => input.remove())
    this.selectedIds().forEach((id) => {
      const input = document.createElement('input')
      input.type = 'hidden'
      input.name = 'ids[]'
      input.value = id
      form.appendChild(input)
    })
  }

  onSubmitEnd (event) {
    if (!event.detail.success) return

    const action = event.target.getAttribute('action')
    if (!action || new URL(action, window.location.href).pathname !== this.pathValue) return

    this.exitMode()
    this.reloadFrame()
  }

  reloadFrame () {
    const frame = this.element.querySelector('turbo-frame#page-index')
    if (!frame) return

    const url = window.location.href
    if (frame.src === url) {
      frame.reload()
    } else {
      frame.src = url
    }
  }

  selectedIds () {
    return this.checkboxTargets.filter((checkbox) => checkbox.checked).map((checkbox) => checkbox.value)
  }

  countLabel (count) {
    return count === 1 ? '1 selezionato' : `${count} selezionati`
  }

  announce (message) {
    if (this.hasStatusTarget) this.statusTarget.textContent = message
  }
}
