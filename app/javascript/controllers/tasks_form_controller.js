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
    'deadlineInfo',
    'timeEstimateInput',
    'timeEstimateBtn'
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
    this.updateTimeEstimateButtons()
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

  onClickDeadlineClear(e) {
    e.preventDefault()
    this.deadlineInputTarget.value = ''
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

  onClickTimeEstimate(e) {
    e.preventDefault()

    const button = e.currentTarget
    const value = button.dataset.value

    this.timeEstimateInputTarget.value = value
    this.updateTimeEstimateButtons()
  }

  onChangeTimeEstimateInput(e) {
    this.updateTimeEstimateButtons()
  }

  updateTimeEstimateButtons() {
    const buttons = this.timeEstimateBtnTargets
    const inputValue = parseInt(this.timeEstimateInputTarget.value) || 0

    buttons.forEach((button) => {
      const buttonValue = parseInt(button.dataset.value)
      if (buttonValue === inputValue) {
        button.classList.add('btn-primary')
        button.classList.remove('btn-outline-primary')
      } else {
        button.classList.add('btn-outline-primary')
        button.classList.remove('btn-primary')
      }
    })
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

  // Reads the content (an email, a message...) and lets the assistant fill
  // title, deadline, estimate, assignee and checklist. The content is kept as is.
  onClickFillFromContent(e) {
    e.preventDefault()

    const contentValue = this.element.querySelector('input[name="content"]').value
    if (!contentValue) {
      alert('Scrivi o incolla un testo nel contenuto del task prima di compilare i campi.')
      return
    }

    const button = e.currentTarget
    const originalButtonText = button.innerText
    button.setAttribute('disabled', true)
    button.innerText = 'Compilazione...'

    fetch('/vectorsearch/text-to-task', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'X-CSRF-Token': document.querySelector('meta[name="csrf-token"]').getAttribute('content')
      },
      body: JSON.stringify({ text: contentValue })
    }).then((response) => {
      return response.json()
    }).then((response) => {
      if (response.error) throw new Error(response.error)

      if (response.title) this.element.querySelector('input[name="title"]').value = response.title
      if (response.deadline) {
        this.deadlineInputTarget.value = response.deadline
        this.updateDeadlineInfo()
      }
      if (response.time_estimate_minutes) {
        this.timeEstimateInputTarget.value = this._closestTimeEstimateOption(response.time_estimate_minutes * 60)
        this.updateTimeEstimateButtons()
      }
      this._selectUser(response.user_id)
      this._appendChecks(response.checklist || [])
    }).catch((error) => {
      console.error(error)
      alert(error.message || 'Si è verificato un errore durante la compilazione dei campi.')
    }).finally(() => {
      button.innerText = originalButtonText
      button.removeAttribute('disabled')
    })
  }

  // the select only accepts fixed estimates: pick the nearest one
  _closestTimeEstimateOption(seconds) {
    const values = Array.from(this.timeEstimateInputTarget.options).map((option) => parseInt(option.value))
    return values.reduce((closest, value) => Math.abs(value - seconds) < Math.abs(closest - seconds) ? value : closest)
  }

  // ignore ids the select does not offer (the model may hallucinate one)
  _selectUser(userId) {
    const select = this.element.querySelector('select[name="user_id"]')
    if (!select || !userId) return
    if (!select.querySelector(`option[value="${userId}"]`)) return

    select.value = userId
  }

  _appendChecks(items) {
    if (!this.hasChecksListTarget || items.length === 0) return

    const checklistAccordion = this.element.querySelector('#formTaskAccordionChecks')
    if (!checklistAccordion.classList.contains('show')) {
      this.element.querySelector('button[data-bs-target="#formTaskAccordionChecks"]').click()
    }

    items.forEach((item) => {
      if (this.checksAddButtonTarget.hasAttribute('disabled')) return

      this.checksAddButtonTarget.click()
      this.checksListTarget.querySelector('li:last-child input').value = item
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
