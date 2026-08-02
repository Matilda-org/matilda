import { Controller } from '@hotwired/stimulus'

// Mirrors the provider detection done server side (Projects::Repository#detect_provider),
// so the select reflects the choice while typing instead of only after the save.
export default class extends Controller {
  static targets = ['urlInput', 'providerInput']

  connect () {
    this._detectProvider = this.detectProvider.bind(this)
    this.urlInputTarget.addEventListener('input', this._detectProvider)
  }

  disconnect () {
    this.urlInputTarget.removeEventListener('input', this._detectProvider)
  }

  detectProvider () {
    const host = this.hostFromUrl(this.urlInputTarget.value)
    if (!host) return

    // Unknown hosts are left untouched: self hosted instances are picked by hand.
    if (host === 'github.com' || host.endsWith('.github.com')) this.providerInputTarget.value = 'github'
    if (host === 'gitlab.com' || host.endsWith('.gitlab.com')) this.providerInputTarget.value = 'gitlab'
  }

  // Accepts the same inputs as the model: https, scheme less and ssh clone urls.
  hostFromUrl (value) {
    const url = value.trim().replace(/^git@([^:/]+):/, 'https://$1/')
    const withScheme = /^https?:\/\//i.test(url) ? url : `https://${url}`

    try {
      return new URL(withScheme).hostname.toLowerCase()
    } catch {
      return null
    }
  }
}
