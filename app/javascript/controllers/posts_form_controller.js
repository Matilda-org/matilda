import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [
    'imageInput',
    'imagePreview',
    'sourceUrlInput',
    'contentInput',
    'tagsInput'
  ]

  connect() {
    this.imagePreviewOriginalSrc = this.imagePreviewTarget.src
    this.imageInputTarget.addEventListener('change', this.handleImageUpload.bind(this))
  }

  handleImageUpload(event) {
    const file = event.target.files[0]
    if (file) {
      const reader = new FileReader()
      reader.onload = (e) => {
        this.imagePreviewTarget.src = e.target.result
      }
      reader.readAsDataURL(file)
    } else {
      this.imagePreviewTarget.src = this.imagePreviewOriginalSrc
    }
  }

  onClickPopulateFromSourceUrl(e) {
    e.preventDefault()

    const sourceUrl = this.sourceUrlInputTarget.value
    if (!sourceUrl) {
      alert('Please enter a source URL.')
      return
    }

    const button = e.currentTarget
    const originalButtonText = button.innerText
    button.setAttribute('disabled', true)
    button.innerText = 'Generazione...'

    fetch('/vectorsearch/url-to-data', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'X-CSRF-Token': document.querySelector('meta[name="csrf-token"]').getAttribute('content')
      },
      body: JSON.stringify({ url: sourceUrl })
    }).then((response) => {
      return response.json()
    }).then((response) => {
      console.log(response)
      if (response.error) {
        alert(response.error)
        button.innerText = originalButtonText
        button.removeAttribute('disabled')
        return
      }

      if (response.content) this.contentInputTarget.value = response.content
      if (response.tags) this.tagsInputTarget.value = response.tags
      if (response.image_url) {
        // download the image and set it on imageInput
        const imageUrl = response.image_url
        fetch(imageUrl)
          .then((response) => {
            if (!response.ok) throw new Error('Network response was not ok')
            return response.blob()
          })
          .then((blob) => {
            const file = new File([blob], 'image.jpg', { type: blob.type })
            const dataTransfer = new DataTransfer()
            dataTransfer.items.add(file)
            this.imageInputTarget.files = dataTransfer.files
            this.handleImageUpload({ target: this.imageInputTarget })
          })
          .catch((error) => {
            console.error('Error downloading image:', error)
          })
      }

      button.innerText = originalButtonText
      button.removeAttribute('disabled')
    }).catch((error) => {
      console.error(error)

      alert('An error occurred while populating the form from the source URL.')
      button.innerText = originalButtonText
      button.removeAttribute('disabled')
    })
  }
}