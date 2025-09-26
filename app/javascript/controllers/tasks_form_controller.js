import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [
    'repeatInput',
    'repeatFields',
    'repeatTypeInput',
    'repeatFieldsWeek',
    'repeatFieldsMonth',
    'checksList',
    'checksTemplate',
    'checksAddButton',
    'deadlineInput',
    'deadlineInfo'
  ]

  connect() {
    if (this.repeatInputTarget.checked) {
      this.activeRepeatFields()
    } else {
      this.deactiveRepeatFields()
    }

    if (this.repeatInputTarget.checked) {
      if (this.repeatTypeInputTarget.value == 'weekly') {
        this.activateRepeatFieldsWeek()
        this.deactivateRepeatFieldsMonth()
      } else if (this.repeatTypeInputTarget.value == 'monthly') {
        this.activateRepeatFieldsMonth()
        this.deactivateRepeatFieldsWeek()
      } else {
        this.deactivateRepeatFieldsWeek()
        this.deactivateRepeatFieldsMonth()
      }
    }

    this.manageChecks()
    this.updateDeadlineInfo()
  }

  onClickDeadlineMinusOne(e) {
    e.preventDefault()

    const currentDate = this.deadlineInputTarget.value ? new Date(this.deadlineInputTarget.value) : new Date()
    currentDate.setDate(currentDate.getDate() - 1)
    this._setDeadlineInputValue(currentDate)
  }

  onClickDeadlinePlusOne(e) {
    e.preventDefault()

    const currentDate = this.deadlineInputTarget.value ? new Date(this.deadlineInputTarget.value) : new Date()
    currentDate.setDate(currentDate.getDate() + 1)
    this._setDeadlineInputValue(currentDate)
  }

  onChangeDeadlineInput(e) {
    this.updateDeadlineInfo()
  }

  _setDeadlineInputValue(date) {
    const yyyy = date.getFullYear()
    let mm = date.getMonth() + 1 // Months start at 0!
    let dd = date.getDate()

    if (dd < 10) dd = '0' + dd
    if (mm < 10) mm = '0' + mm

    this.deadlineInputTarget.value = `${yyyy}-${mm}-${dd}`
    this.updateDeadlineInfo()
  }

  updateDeadlineInfo() {
    if (!this.deadlineInputTarget.value) {
      this.deadlineInfoTarget.innerText = 'Nessuna scadenza'
      return
    }

    const date = new Date(this.deadlineInputTarget.value)
    if (isNaN(date)) {
      this.deadlineInfoTarget.innerText = 'Data non valida'
      return
    }

    // Imposta label scadenza tra: oggi, domani, dopo domani, ieri, l'altro ieri, tra X giorni, X giorni fa, il 25 Dicembre 2023
    const today = new Date()
    today.setHours(0, 0, 0, 0)
    const diffTime = date - today
    const diffDays = Math.round(diffTime / (1000 * 60 * 60 * 24))

    let label = ''
    if (diffDays === 0) {
      label = 'Oggi'
    } else if (diffDays === 1) {
      label = 'Domani'
    } else if (diffDays === -1) {
      label = 'Ieri'
    } else if (diffDays > 1 && diffDays <= 30) {
      label = `Tra ${diffDays} giorni`
    } else if (diffDays < -1 && diffDays >= -30) {
      label = `${Math.abs(diffDays)} giorni fa`
    } else {
      const options = { year: 'numeric', month: 'long', day: 'numeric' }
      label = `Il ${date.toLocaleDateString('it-IT', options)}`
    }

    // Aggiungo il nome del giorno della settimana
    const daysOfWeek = ['Domenica', 'Lunedì', 'Martedì', 'Mercoledì', 'Giovedì', 'Venerdì', 'Sabato']
    const dayName = daysOfWeek[date.getDay()]
    label += ` (${dayName})`

    this.deadlineInfoTarget.innerText = label
  }

  onChangeRepeat(e) {
    if (e.target.checked) {
      this.activeRepeatFields()
    } else {
      this.deactiveRepeatFields()
    }
  }

  onChangeRepeatType(e) {
    if (this.repeatInputTarget.checked) {
      if (e.target.value == 'weekly') {
        this.activateRepeatFieldsWeek()
        this.deactivateRepeatFieldsMonth()
      } else if (e.target.value == 'monthly') {
        this.activateRepeatFieldsMonth()
        this.deactivateRepeatFieldsWeek()
      } else {
        this.deactivateRepeatFieldsWeek()
        this.deactivateRepeatFieldsMonth()
      }
    }
  }

  onClickAddCheck(e) {
    e.preventDefault()

    const newCheck = this.checksTemplateTarget.children[0].cloneNode(true)
    const newCheckInput = newCheck.querySelector('input')
    newCheckInput.removeAttribute('disabled')
    newCheckInput.setAttribute('required', true)
    newCheckInput.id = newCheckInput.id.replace('[template]', `[${Math.floor(Math.random() * 1000)}]`)
    newCheckInput.value = ''
    this.checksListTarget.appendChild(newCheck)

    this.manageChecks()
  }

  onClickRemoveCheck(e) {
    e.preventDefault()

    e.target.closest('li').remove()
    this.manageChecks()
  }

  onClickConvertContentToChecklist(e) {
    e.preventDefault()

    const contentValue = this.element.querySelector('input[name="content"]').value
    if (!contentValue) {
      alert('Please enter a task content before converting it to a checklist.')
      return
    }

    const button = e.currentTarget
    const originalButtonText = button.innerText
    button.setAttribute('disabled', true)
    button.innerText = 'Conversione...'

    fetch('/vectorsearch/text-to-checklist', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'X-CSRF-Token': document.querySelector('meta[name="csrf-token"]').getAttribute('content')
      },
      body: JSON.stringify({ text: contentValue })
    }).then((response) => {
      return response.json()
    }).then((response) => {
      const checklistAccordion = this.element.querySelector('#formTaskAccordionChecks')
      if (!checklistAccordion.classList.contains('show')) {
        const checklistAccordionButton = this.element.querySelector('button[data-bs-target="#formTaskAccordionChecks"]')
        checklistAccordionButton.click()
      }

      response.map((item) => {
        this.checksAddButtonTarget.click()
        const newCheck = this.checksListTarget.querySelector('li:last-child')
        const newCheckInput = newCheck.querySelector('input')
        newCheckInput.value = item
      })

      button.innerText = originalButtonText
      button.removeAttribute('disabled')
    }).catch((error) => {
      console.error(error)

      alert('An error occurred while converting the content to a checklist.')
      button.innerText = originalButtonText
      button.removeAttribute('disabled')
    })
  }

  activeRepeatFields() {
    this.repeatFieldsTarget.classList.remove('d-none')

    this.repeatFieldsTarget.querySelectorAll('input, select').forEach((input) => {
      input.setAttribute('required', true)
    })
  }

  deactiveRepeatFields() {
    this.repeatFieldsTarget.classList.add('d-none')

    this.repeatFieldsTarget.querySelectorAll('input, select').forEach((input) => {
      input.removeAttribute('required')
    })
  }

  activateRepeatFieldsWeek() {
    this.repeatFieldsWeekTarget.classList.remove('d-none')

    this.repeatFieldsWeekTarget.querySelectorAll('input, select').forEach((input) => {
      input.setAttribute('required', true)
    })
  }

  deactivateRepeatFieldsWeek() {
    this.repeatFieldsWeekTarget.classList.add('d-none')

    this.repeatFieldsWeekTarget.querySelectorAll('input, select').forEach((input) => {
      input.removeAttribute('required')
    })
  }

  activateRepeatFieldsMonth() {
    this.repeatFieldsMonthTarget.classList.remove('d-none')

    this.repeatFieldsMonthTarget.querySelectorAll('input, select').forEach((input) => {
      input.setAttribute('required', true)
    })
  }

  deactivateRepeatFieldsMonth() {
    this.repeatFieldsMonthTarget.classList.add('d-none')

    this.repeatFieldsMonthTarget.querySelectorAll('input, select').forEach((input) => {
      input.removeAttribute('required')
    })
  }

  manageChecks() {
    if (!this.hasChecksListTarget) return

    const items = this.checksListTarget.querySelectorAll('li')
    if (items.length >= 10) {
      this.checksAddButtonTarget.setAttribute('disabled', true)
    } else {
      this.checksAddButtonTarget.removeAttribute('disabled')
    }

    if (items.length > 0) {
      this.checksListTarget.classList.remove('d-none')
    } else {
      this.checksListTarget.classList.add('d-none')
    }
  }
}
