import { Controller } from "@hotwired/stimulus"

export default class extends Controller {

  connect() {
    this.tooltip = new bootstrap.Carousel(this.element, {
      interval: 5000,
      wrap: false
    })
  }

}