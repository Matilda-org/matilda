import { Controller } from "@hotwired/stimulus"

// Asks the assistant for a draft of a CRM communication (first message or
// reminder) and shows it in an editable textarea, ready to be copied.
export default class extends Controller {
  static targets = ['button', 'output', 'text']
  static values = { id: Number }

  generate(e) {
    e.preventDefault()

    const button = e.currentTarget
    const originalButtonHtml = button.innerHTML
    button.setAttribute('disabled', true)
    button.innerText = 'Generazione...'

    fetch('/vectorsearch/communication-draft', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'X-CSRF-Token': document.querySelector('meta[name="csrf-token"]').getAttribute('content')
      },
      body: JSON.stringify({ communication_id: this.idValue })
    }).then((response) => {
      return response.json()
    }).then((response) => {
      if (response.error) throw new Error(response.error)

      this.textTarget.value = response.draft
      this.outputTarget.classList.remove('d-none')
      this.buttonTarget.classList.add('d-none')
    }).catch((error) => {
      console.error(error)
      alert(error.message || 'Si è verificato un errore durante la generazione della bozza.')
    }).finally(() => {
      button.innerHTML = originalButtonHtml
      button.removeAttribute('disabled')
    })
  }

  copy(e) {
    e.preventDefault()

    const button = e.currentTarget
    const originalButtonHtml = button.innerHTML
    navigator.clipboard.writeText(this.textTarget.value).then(() => {
      button.innerHTML = '<i class="bi bi-check2 me-1"></i>Copiata'
      window.setTimeout(() => { button.innerHTML = originalButtonHtml }, 1500)
    })
  }
}
