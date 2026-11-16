import { Controller } from '@hotwired/stimulus'

const DEBOUNCE_MS = 250

// Navbar search palette (ARIA combobox): typing loads grouped matches into the
// results turbo-frame, arrows move through them, Enter opens the highlighted one
// or submits to the dashboard search. Ctrl/⌘+K focuses it from anywhere; on
// mobile the navbar search icon opens it as a full-width sheet.
export default class extends Controller {
  static targets = ['input', 'hint', 'panel', 'results']
  static values = { url: String }

  connect () {
    this.index = -1
    if (this.hasHintTarget && /Mac|iPhone|iPad/.test(navigator.platform)) this.hintTarget.textContent = '⌘ K'
  }

  disconnect () {
    clearTimeout(this.timer)
  }

  shortcut (event) {
    if (event.key?.toLowerCase() !== 'k' || !(event.metaKey || event.ctrlKey)) return

    event.preventDefault()
    this.open()
    this.inputTarget.select()
  }

  search () {
    clearTimeout(this.timer)
    this.timer = setTimeout(() => this.load(), DEBOUNCE_MS)
  }

  // The frame drops stale responses itself: a new src cancels the pending request
  load () {
    const url = new URL(this.urlValue, window.location.origin)
    url.searchParams.set('q', this.inputTarget.value.trim())
    this.resultsTarget.src = url.pathname + url.search
    this.open()
  }

  loaded () {
    this.highlight(-1)
  }

  // A prefilled field (dashboard search) has no results loaded yet
  reopen () {
    if (!this.isOpen) this.open()
    if (!this.resultsTarget.src && this.inputTarget.value.trim().length >= 3) this.load()
  }

  open () {
    this.element.classList.add('is-open')
    this.panelTarget.hidden = false
    this.inputTarget.setAttribute('aria-expanded', 'true')
    if (document.activeElement !== this.inputTarget) this.inputTarget.focus()
  }

  close () {
    this.element.classList.remove('is-open')
    this.panelTarget.hidden = true
    this.inputTarget.setAttribute('aria-expanded', 'false')
    this.highlight(-1)
  }

  navigate (event) {
    switch (event.key) {
      case 'ArrowDown':
      case 'ArrowUp':
        event.preventDefault()
        if (!this.isOpen) this.open()
        this.move(event.key === 'ArrowDown' ? 1 : -1)
        break
      case 'Enter':
        if (this.index < 0) return

        event.preventDefault()
        this.options[this.index]?.click()
        break
      case 'Tab':
        if (this.isOpen) this.close()
        break
      case 'Escape':
        event.preventDefault()
        this.close()
        this.inputTarget.blur()
        break
    }
  }

  // One window listener covers the mobile opener (outside this element, so no
  // Stimulus action can reach it), choosing a result and clicking outside.
  clickOutside (event) {
    if (event.target.closest('[data-global-search-open]')) {
      event.preventDefault()
      this.open()
    } else if (!this.element.contains(event.target) || event.target.closest('[role="option"]')) {
      if (this.isOpen) this.close()
    }
  }

  move (delta) {
    const count = this.options.length
    if (!count) return

    const start = this.index < 0 && delta < 0 ? count : this.index
    this.highlight((start + delta + count) % count)
  }

  highlight (index) {
    this.index = index
    this.options.forEach((option, i) => {
      const active = i === index
      option.setAttribute('aria-selected', active)
      option.classList.toggle('is-active', active)
      if (active) option.scrollIntoView({ block: 'nearest' })
    })

    const active = this.options[index]
    if (active) {
      this.inputTarget.setAttribute('aria-activedescendant', active.id)
    } else {
      this.inputTarget.removeAttribute('aria-activedescendant')
    }
  }

  get options () {
    return [...this.resultsTarget.querySelectorAll('[role="option"]')]
  }

  get isOpen () {
    return this.element.classList.contains('is-open')
  }
}
