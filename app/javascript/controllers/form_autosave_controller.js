import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [
    'updateStatus'
  ]

  connect() {
    this.interval = setInterval(() => {
      this.autosave()
    }, 1500)

    this.formFieldsValues = this.getFormFieldsValues()
  }

  disconnect() {
    if (this.interval) {
      clearInterval(this.interval)
    }
  }

  autosave() {
    const newFormFieldsValues = this.getFormFieldsValues()
    if (this.formFieldsValues === newFormFieldsValues) {
      return
    }
    this.formFieldsValues = newFormFieldsValues

    if (this.hasUpdateStatusTarget) {
      this.updateStatusTarget.classList.remove('d-none')
    }

    const formAction = this.element.getAttribute('action')
    const formMethod = this.element.getAttribute('method')
    const formData = new FormData(this.element)
    formData.append('_autosave', true)

    fetch(formAction, {
      method: formMethod,
      body: formData
    }).then((response) => {
      if (response.ok) {
        if (this.hasUpdateStatusTarget) {
          const now = new Date()
          let nowHours = now.getHours()
          let nowMinutes = now.getMinutes()
          let nowSeconds = now.getSeconds()
          if (nowHours < 10) {
            nowHours = '0' + nowHours
          }
          if (nowMinutes < 10) {
            nowMinutes = '0' + nowMinutes
          }
          if (nowSeconds < 10) {
            nowSeconds = '0' + nowSeconds
          }
          this.updateStatusTarget.innerHTML = `Salvato alle ${nowHours}:${nowMinutes}:${nowSeconds}`
        }
      } else {
        console.error(response)

        if (this.hasUpdateStatusTarget) {
          this.updateStatusTarget.innerHTML = 'Errore salvataggio'
        }
      }
    })
  }

  getFormFieldsValues() {
    // considering this.element is the form, take a json string with all the form fields values
    const formData = new FormData(this.element)
    const formFields = {}
    formData.forEach((value, key) => {
      formFields[key] = value
    })
    return JSON.stringify(formFields)
  } 
}
