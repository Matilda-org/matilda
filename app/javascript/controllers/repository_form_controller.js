import { Controller } from '@hotwired/stimulus'

// Provider detection lives here only: the model just validates its presence,
// so the select is filled from the url while typing and stays editable for self hosted instances.
export default class extends Controller {
  static targets = ['urlInput', 'providerInput']

  // A prefilled url (form re-rendered after an error) still gets its provider, unless one is already picked.
  connect () {
    if (!this.providerInputTarget.value) this.detectProvider()
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
