import Clipboard from 'stimulus-clipboard'

export default class extends Clipboard {
  connect() {
    super.connect()
    // preserve original markup (base lib uses innerText, dropping icons)
    if (this.hasButtonTarget) this.originalHTML = this.buttonTarget.innerHTML
  }

  // override to render HTML success content (icons) instead of plain text
  copied() {
    if (!this.hasButtonTarget) return

    if (this.timeout) clearTimeout(this.timeout)

    this.buttonTarget.innerHTML = this.data.get('successContent')
    this.timeout = setTimeout(() => {
      this.buttonTarget.innerHTML = this.originalHTML
    }, this.successDurationValue)
  }
}
