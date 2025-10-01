import { Controller } from '@hotwired/stimulus'

export default class extends Controller {
  static targets = ['input']

  connect() {
    // Inizializza il componente
    this.updateVisualState()
  }

  updateSelection(event) {
    // Aggiorna lo stato visuale quando viene selezionato un colore
    this.updateVisualState()
    
    // Dispatch evento personalizzato per notificare la selezione
    const selectedValue = event.target.value
    const customEvent = new CustomEvent('input-color:changed', {
      detail: { 
        value: selectedValue,
        element: this.element 
      },
      bubbles: true
    })
    
    this.element.dispatchEvent(customEvent)
  }

  updateVisualState() {
    // Aggiorna lo stato visuale di tutti gli input
    this.inputTargets.forEach(input => {
      const label = input.nextElementSibling
      const circle = label.querySelector('.c-input-color__circle')
      
      if (input.checked) {
        circle.classList.add('selected')
      } else {
        circle.classList.remove('selected')
      }
    })
  }

  // Metodo per impostare programmaticamente il colore selezionato
  setValue(colorValue) {
    const targetInput = this.inputTargets.find(input => input.value === colorValue)
    
    if (targetInput) {
      // Deseleziona tutti gli altri
      this.inputTargets.forEach(input => input.checked = false)
      
      // Seleziona il target
      targetInput.checked = true
      
      // Aggiorna lo stato visuale
      this.updateVisualState()
      
      // Trigger change event
      targetInput.dispatchEvent(new Event('change'))
    }
  }

  // Metodo per ottenere il valore selezionato
  getValue() {
    const selectedInput = this.inputTargets.find(input => input.checked)
    return selectedInput ? selectedInput.value : null
  }
}