import { Controller } from "@hotwired/stimulus"
import { crypt, decrypt } from 'libs/crypter'

export default class extends Controller {
  static targets = [
    'budgetManagementInput',
    'budgetMoneyInput',
    'budgetTimeInput',
    'budgetMoneyPerTimeInput',
    'budgetMoneyInputContainer',
    'budgetTimeInputContainer',
    'budgetMoneyPerTimeContainer'
  ]

  connect() {
    this.manageBudgetManagement()
    this._manageBudgetManagement = this.manageBudgetManagement.bind(this)

    this.manageBudgetChange()
    this._manageBudgetChange = this.manageBudgetChange.bind(this)

    this.budgetManagementInputTarget.addEventListener('change', this._manageBudgetManagement)
    this.budgetMoneyInputTarget.addEventListener('change', this._manageBudgetChange)
    this.budgetMoneyInputTarget.addEventListener('keyup', this._manageBudgetChange)
    this.budgetTimeInputTarget.addEventListener('change', this._manageBudgetChange)
  }

  disconnect() {
    this.budgetManagementInputTarget.removeEventListener('change', this._manageBudgetManagement)
  }

  manageBudgetManagement() {
    const isChecked = this.budgetManagementInputTarget.checked
    if (isChecked) {
      this.budgetMoneyInputContainerTarget.classList.remove('d-none')
      this.budgetTimeInputContainerTarget.classList.remove('d-none')
      this.budgetMoneyPerTimeContainerTarget.classList.remove('d-none')
    } else {
      this.budgetMoneyInputContainerTarget.classList.add('d-none')
      this.budgetTimeInputContainerTarget.classList.add('d-none')
      this.budgetMoneyPerTimeContainerTarget.classList.add('d-none')
    }
  }

  manageBudgetChange() {
    const budgetMoney = this.budgetMoneyInputTarget.value
    const budgetTime = this.budgetTimeInputTarget.value

    if (budgetMoney && budgetTime) {
      const budgetTimeHours = budgetTime / 3600
      const budgetMoneyPerTime = Math.round(budgetMoney / budgetTimeHours * 100) / 100
      this.budgetMoneyPerTimeInputTarget.value = budgetMoneyPerTime
    } else {
      this.budgetMoneyPerTimeInputTarget.value = ''
    }
  }
}