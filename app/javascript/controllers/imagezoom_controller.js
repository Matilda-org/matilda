import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
    this.zoomInBinded = this.zoomIn.bind(this)

    this.element.addEventListener('click', this.zoomInBinded)
  }

  disconnect() {
    this.element.removeEventListener('click', this.zoomInBinded)
  }

  zoomIn(e) {
    e.preventDefault()

    const imagezoom = this.getImageZoom()
    imagezoom.innerHTML = ''
    
    const image = document.createElement('img')
    image.src = this.element.src
    imagezoom.appendChild(image)

    imagezoom.classList.add('is-active')
  }

  getImageZoom() {
    let imagezoom = document.getElementById('imagezoom')
    if (!imagezoom) {
      imagezoom = document.createElement('div')
      imagezoom.id = 'imagezoom'
      imagezoom.classList.add('c-imagezoom')
      document.body.appendChild(imagezoom)

      imagezoom.addEventListener('click', (e) => {
        e.preventDefault()
        imagezoom.classList.remove('is-active')
      })
    }

    return imagezoom
  }
}