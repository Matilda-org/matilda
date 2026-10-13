import { Controller } from "@hotwired/stimulus"

// Lets the assistant fill the contact form from a pasted email signature
// and/or a photo of a business card. Each field target is matched by its name.
export default class extends Controller {
  static targets = ['aiText', 'aiImage', 'field']

  onClickFill(e) {
    e.preventDefault()

    const text = this.aiTextTarget.value.trim()
    const image = this.aiImageTarget.files[0]
    if (!text && !image) {
      alert('Incolla un testo o scegli un\'immagine prima di compilare i campi.')
      return
    }

    // multipart: the image travels as a file, no base64 in the browser
    const body = new FormData()
    if (text) body.append('text', text)
    if (image) body.append('image', image)

    const button = e.currentTarget
    const originalButtonText = button.innerText
    button.setAttribute('disabled', true)
    button.innerText = 'Compilazione...'

    fetch('/vectorsearch/text-to-contact', {
      method: 'POST',
      headers: {
        'X-CSRF-Token': document.querySelector('meta[name="csrf-token"]').getAttribute('content')
      },
      body
    }).then((response) => {
      return response.json()
    }).then((response) => {
      if (response.error) throw new Error(response.error)

      // only overwrite with real values: null means the model found nothing
      this.fieldTargets.forEach((field) => {
        if (response[field.name]) field.value = response[field.name]
      })
    }).catch((error) => {
      console.error(error)
      alert(error.message || 'Si è verificato un errore durante la compilazione dei campi.')
    }).finally(() => {
      button.innerText = originalButtonText
      button.removeAttribute('disabled')
    })
  }
}
