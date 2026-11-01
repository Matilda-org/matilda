import { Controller } from '@hotwired/stimulus'

const THEMES = ['auto', 'light', 'dark']
const LABELS = { auto: 'Tema: automatico', light: 'Tema: chiaro', dark: 'Tema: scuro' }
const ICONS = { auto: 'bi-circle-half', light: 'bi-sun-fill', dark: 'bi-moon-stars-fill' }

// Cycles auto → light → dark. The choice lives in localStorage and is applied
// before first paint by the inline script in the layout head; "auto" follows
// the operating system, live.
export default class extends Controller {
  static targets = ['icon', 'label']

  connect () {
    this.systemQuery = window.matchMedia('(prefers-color-scheme: dark)')
    this.onSystemChange = () => this.apply()
    this.systemQuery.addEventListener('change', this.onSystemChange)
    this.render()
  }

  disconnect () {
    this.systemQuery.removeEventListener('change', this.onSystemChange)
  }

  cycle () {
    const next = THEMES[(THEMES.indexOf(this.theme) + 1) % THEMES.length]
    try { window.localStorage.setItem('theme', next) } catch {}
    this.apply()
    this.render()
  }

  apply () {
    const dark = this.theme === 'dark' || (this.theme === 'auto' && this.systemQuery.matches)
    document.documentElement.dataset.bsTheme = dark ? 'dark' : 'light'
  }

  render () {
    const label = LABELS[this.theme]
    this.element.setAttribute('aria-label', label)
    this.element.dataset.tooltip = label
    window.bootstrap?.Tooltip.getInstance(this.element)?.setContent({ '.tooltip-inner': label })
    if (this.hasIconTarget) this.iconTarget.className = `bi ${ICONS[this.theme]}`
    if (this.hasLabelTarget) this.labelTarget.textContent = label
  }

  get theme () {
    try {
      const stored = window.localStorage.getItem('theme')
      return THEMES.includes(stored) ? stored : 'auto'
    } catch {
      return 'auto'
    }
  }
}
