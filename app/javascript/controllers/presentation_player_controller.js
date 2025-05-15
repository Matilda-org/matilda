import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = {
    width: { type: Number, default: 1920 },
    height: { type: Number, default: 1080 },
    ratio: { type: Boolean, default: false },
  }

  connect() {
    let currentWidth = this.element.clientWidth
    let currentHeight = this.element.clientHeight

    let targetWidth = this.widthValue
    let targetHeight = this.heightValue
    let targetRatio = targetWidth / targetHeight

    if (currentWidth > targetWidth) {
      currentWidth = targetWidth
    }

    if (this.ratioValue) {
      while (currentWidth / currentHeight > targetRatio) {
        currentWidth--
      }

      while (currentWidth / currentHeight < targetRatio) {
        currentHeight--
      }
    }

    this.element.style.width = currentWidth + "px"
    this.element.style.height = currentHeight + "px"
    this.element.classList.add('is-active')
  }
}