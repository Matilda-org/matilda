import { Controller } from "@hotwired/stimulus"
import { flashOn, flashOff } from 'libs/titleflash'

export default class extends Controller {
  static targets = [
    'time',
    'ping',
    'ctaShow'
  ]

  static values = {
    start: { type: Number, default: 0 },
    pingpath: { type: String, default: '' },
  }

  connect() {
    const nowSeconds = Math.round((new Date()).getTime() / 1000)
    this.seconds = nowSeconds - this.startValue

    if (this.hasTimeTarget) {
      this.intervalUI = setInterval(this.updateUi.bind(this), 1000)
      this.updateUi()
    }
    
    if (this.pingpathValue) {
      this.intervalPing = setInterval(this.pingTrack.bind(this), 10000)
    }

    flashOn(`⌛️ TIME TRACKING ATTIVO`)
  }

  disconnect() {
    if (this.intervalUI) clearInterval(this.intervalUI)
    if (this.intervalPing) clearInterval(this.intervalPing)


    flashOff()
  }

  updateUi() {
    this.seconds++

    const hours = Math.floor(this.seconds / 3600)
    const minutes = Math.floor((this.seconds - hours * 3600) / 60)
    const seconds = this.seconds - hours * 3600 - minutes * 60

    this.timeTarget.innerText = `${this.numberToTime(hours)}:${this.numberToTime(minutes)}:${this.numberToTime(seconds)}`
  }

  pingTrack() {
    fetch(this.pingpathValue, { method: 'POST', headers: {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      'X-CSRF-Token': document.querySelector('meta[name="csrf-token"]').content
    }}).then(() => {
      console.log('Ping tracking!')
    })
  }

  numberToTime(number) {
    if (number < 10) {
      return `0${number}`
    }

    return number
  }
}
