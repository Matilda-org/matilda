import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="api-key-generator"
export default class extends Controller {
  static targets = ["input"]

  generate() {
    // Genera una API key casuale di 32 caratteri
    const apiKey = this.generateApiKey(32)
    this.inputTarget.value = apiKey
    
    // Trigger del change event per eventuali altri listener
    this.inputTarget.dispatchEvent(new Event('change', { bubbles: true }))
  }

  generateApiKey(length = 32) {
    const characters = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789'
    let result = ''
    
    for (let i = 0; i < length; i++) {
      result += characters.charAt(Math.floor(Math.random() * characters.length))
    }
    
    return result
  }
}
