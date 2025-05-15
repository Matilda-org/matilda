import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ['item']

  connect() {
    
  }

  itemTargetConnected(element) {
    const policies = this.loadPolicies()

    const itemPolicy = element.getAttribute('data-policy')
    if (policies.includes(itemPolicy) || !itemPolicy) {
      element.removeAttribute('data-user-policies-target')
    }
  }

  loadPolicies() {
    if (this.policies) return this.policies

    this.policies = this.element.getAttribute('data-user-policies-list')?.split(',')
    return this.policies
  }
}