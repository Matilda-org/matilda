import { Controller } from "@hotwired/stimulus"
import dragula from 'dragula'

export default class extends Controller {
  static targets = [
    'nav',
    'navPage',
    'toggleAction',
    'toggleNote',
    'player',
    'actionAddAction',
    'actionAddNote'
  ]

  static values = {
    toggleType: { type: String, default: '' }
  }

  connect() {
    // setup dragula to manage nav draggable pages
    this.dragula = dragula([this.navTarget], {
      accepts: (el, target) => {
        return true
      },
      invalid: (el, handle) => {
        return false
      },
    })
    this.dragula.on('drop', this.onNavPageDrop.bind(this))
  }

  onNavPageDrop(el, target) {
    const page = el.dataset.page
    const order = Array.from(target.children).indexOf(el) + 1
    const updater = el.querySelector('.presentation-editor_controller-nav-page-updater')
    if (!updater) return

    const updaterUrl = new URL(updater.href)
    updaterUrl.searchParams.set('page_id', page)
    updaterUrl.searchParams.set('order', order)
    updater.href = updaterUrl.href

    updater.click()
  }

  toggleNote(e) {
    e.preventDefault()

    if (this.toggleTypeValue != 'note') {
      this.toggleTypeValue = 'note'
    } else {
      this.toggleTypeValue = ''
    }
  }

  toggleAction(e) {
    e.preventDefault()

    if (this.toggleTypeValue != 'action') {
      this.toggleTypeValue = 'action'
    } else {
      this.toggleTypeValue = ''
    }
  }

  clickPlayer(e) {
    if (this.toggleTypeValue == '') return

    const percentageX = (e.offsetX / e.target.clientWidth) * 100 
    const percentageY = (e.offsetY / e.target.clientHeight) * 100

    if (this.toggleTypeValue == 'action') {
      const actionUrl = new URL(this.actionAddActionTarget.href)
      actionUrl.searchParams.set('position_x', percentageX)
      actionUrl.searchParams.set('position_y', percentageY)
      this.actionAddActionTarget.href = actionUrl.href
      this.actionAddActionTarget.click()
    } else if (this.toggleTypeValue == 'note') {
      const noteUrl = new URL(this.actionAddNoteTarget.href)
      noteUrl.searchParams.set('position_x', percentageX)
      noteUrl.searchParams.set('position_y', percentageY)
      this.actionAddNoteTarget.href = noteUrl.href
      this.actionAddNoteTarget.click()
    }

    this.toggleTypeValue = ''
  }

  navTargetConnected(element) {
    if (!this.dragula) return

    this.dragula.containers.push(element)
  }

  navTargetDisconnected(element) {
    if (!this.dragula) return

    this.dragula.containers.splice(this.dragula.containers.indexOf(element), 1)
  }

  toggleTypeValueChanged() {
    if (this.toggleTypeValue === 'note') {
      if (this.hasToggleActionTarget) {
        this.toggleActionTarget.classList.remove('btn-info')
        this.toggleActionTarget.classList.add('btn-secondary')
      }

      if (this.hasToggleNoteTarget) {
        this.toggleNoteTarget.classList.remove('btn-secondary')
        this.toggleNoteTarget.classList.add('btn-warning')
      }

      if (this.hasPlayerTarget) {
        this.playerTarget.classList.add('is-editable')
      }
    } else if (this.toggleTypeValue === 'action') {
      if (this.hasToggleNoteTarget) {
        this.toggleNoteTarget.classList.remove('btn-warning')
        this.toggleNoteTarget.classList.add('btn-secondary')
      }

      if (this.hasToggleActionTarget) {
        this.toggleActionTarget.classList.remove('btn-secondary')
        this.toggleActionTarget.classList.add('btn-info')
      }

      if (this.hasPlayerTarget) {
        this.playerTarget.classList.add('is-editable')
      }
    } else {
      if (this.hasToggleNoteTarget) {
        this.toggleNoteTarget.classList.remove('btn-warning')
        this.toggleNoteTarget.classList.add('btn-secondary')
      }

      if (this.hasToggleActionTarget) {
        this.toggleActionTarget.classList.remove('btn-info')
        this.toggleActionTarget.classList.add('btn-secondary')
      }

      if (this.hasPlayerTarget) {
        this.playerTarget.classList.remove('is-editable')
      }
    }
  }
}