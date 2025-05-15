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
