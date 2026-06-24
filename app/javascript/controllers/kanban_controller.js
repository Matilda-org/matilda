import { Controller } from "@hotwired/stimulus"
import dragula from 'dragula'
// import { debounce } from 'libs/utils'

export default class extends Controller {
  static targets = [
    'container',
    'prev',
    'next',
    'scrollable',
    'announcer'
  ]

  static values = {
    updaterParamContainer: { type: String, default: 'container' },
    updaterParamItem: { type: String, default: 'item' },
    updaterParamOrder: { type: String, default: 'order' }
  }

  connect() {
    this.dragula = dragula(this.containerTargets.concat([this.prevTarget, this.nextTarget]), {
      accepts: (el, target) => {
        let accepted = true
        if (target == this.prevTarget) {
          this.scrollableTarget.scrollLeft -= 50
          this.prevTarget.classList.add('is-over')
          accepted = false
        }
        if (target == this.nextTarget) {
          this.scrollableTarget.scrollLeft += 50
          this.nextTarget.classList.add('is-over')
          accepted = false
        }

        if (accepted) this.element.classList.add('is-dragging')

        return accepted
      },
      invalid: (el, handle) => {
        return !handle.classList.contains('kanban_controller-move-button')
      },
    })

    this.dragula.on('over', this.onOver.bind(this))
    this.dragula.on('drag', this.onDrag.bind(this))
    this.dragula.on('dragend', this.onDragEnd.bind(this))
    this.dragula.on('drop', this.onDrop.bind(this))

    // this.lastScrollLeft = 0
    // this._onScrollDebounced = debounce(this.onScroll.bind(this), 500)
    // this.scrollableTarget.addEventListener('scroll', this._onScrollDebounced)
  }

  // onScroll(e) {
  //   // detect scroll direction
  //   const scrollDirection = this.scrollableTarget.scrollLeft > this.lastScrollLeft ? 'right' : 'left'
  //   this.lastScrollLeft = this.scrollableTarget.scrollLeft

  //   // detect children not in parent viewport
  //   const parentPosition = this.scrollableTarget.getBoundingClientRect()
  //   const children = Array.from(this.scrollableTarget.children)
  //   const childrenNotInViewport = children.filter(child => {
  //     const rect = child.getBoundingClientRect()
  //     return scrollDirection == 'right' ? rect.right > parentPosition.right : rect.left < parentPosition.left
  //   })
  //   if (childrenNotInViewport.length == children.length) return
  //   if (childrenNotInViewport.length == 0) return

  //   // detect children to scroll to
  //   const childrenToScrollTo = scrollDirection == 'right' ? childrenNotInViewport[0] : childrenNotInViewport[childrenNotInViewport.length - 1]
  //   if (!childrenToScrollTo) return

  //   // be sure childrenToScrollTo is in viewport for 75% of its width
  //   const childrenToScrollToRect = childrenToScrollTo.getBoundingClientRect()
  //   const childrenToScrollToWidth = childrenToScrollTo.offsetWidth
  //   const childrenToScrollToInViewportWidth = scrollDirection == 'right' ? childrenToScrollToRect.right - parentPosition.left : parentPosition.right - childrenToScrollToRect.left
  //   if (childrenToScrollToInViewportWidth < childrenToScrollToWidth * 0.75) return

  //   // remove scroll event listener to avoid infinite loop
  //   this.scrollableTarget.removeEventListener('scroll', this._onScrollDebounced)

  //   // scroll to make children in viewport
  //   this.scrollableTarget.scrollLeft = scrollDirection == 'right' ? childrenToScrollTo.offsetLeft + childrenToScrollTo.offsetWidth - this.scrollableTarget.offsetWidth : childrenToScrollTo.offsetLeft - this.scrollableTarget.offsetWidth

  //   // re-add scroll event listener after scroll
  //   setTimeout(() => {
  //     this.scrollableTarget.addEventListener('scroll', this._onScrollDebounced)
  //   }, 100)
  // }

  onOver() {
    this.prevTarget.classList.remove('is-over')
    this.nextTarget.classList.remove('is-over')
  }

  onDrag() {
    this.prevTarget.classList.add('is-active')
    this.nextTarget.classList.add('is-active')

    // this.element.classList.add('is-dragging')
  }

  onDragEnd() {
    this.prevTarget.classList.remove('is-active')
    this.nextTarget.classList.remove('is-active')

    this.element.classList.remove('is-dragging')
  }

  onDrop(el, target) {
    const order = Array.from(target.children).indexOf(el) + 1
    this.commitMove(el, target, order)
  }

  // Alternativa da tastiera al drag&drop: con il focus sul pulsante "sposta"
  // le frecce spostano l'elemento tra le colonne (sinistra/destra) e all'interno
  // della colonna (su/giù).
  moveKeydown(e) {
    const directions = {
      ArrowLeft: 'left',
      ArrowRight: 'right',
      ArrowUp: 'up',
      ArrowDown: 'down'
    }
    const direction = directions[e.key]
    if (!direction) return

    const itemEl = e.target.closest('[data-item]')
    if (!itemEl) return
    const currentContainer = itemEl.parentElement
    if (!currentContainer) return

    e.preventDefault()

    const containers = this.containerTargets
    const containerIndex = containers.indexOf(currentContainer)
    const siblings = Array.from(currentContainer.children)
    const currentIndex = siblings.indexOf(itemEl)

    if (direction == 'left' || direction == 'right') {
      const targetContainer = containers[containerIndex + (direction == 'left' ? -1 : 1)]
      if (!targetContainer) return

      const order = targetContainer.children.length + 1
      this.commitMove(itemEl, targetContainer, order)
    } else {
      const newIndex = currentIndex + (direction == 'up' ? -1 : 1)
      if (newIndex < 0 || newIndex > siblings.length - 1) return

      this.commitMove(itemEl, currentContainer, newIndex + 1)
    }
  }

  commitMove(itemEl, containerEl, order) {
    const updater = itemEl.querySelector('.kanban_controller-item-updater')
    if (!updater) return

    const updaterUrl = new URL(updater.href)
    updaterUrl.searchParams.set(this.updaterParamContainerValue, containerEl.dataset.container)
    updaterUrl.searchParams.set(this.updaterParamItemValue, itemEl.dataset.item)
    updaterUrl.searchParams.set(this.updaterParamOrderValue, order)
    updater.href = updaterUrl.href

    this.announce(itemEl, containerEl, order)
    this.restoreFocus(itemEl.id)

    updater.click()
  }

  announce(itemEl, containerEl, order) {
    if (!this.hasAnnouncerTarget) return

    const title = itemEl.querySelector('.c-kanban__item-title')?.textContent?.trim() || 'Elemento'
    const column = containerEl.dataset.statusTitle || ''
    this.announcerTarget.textContent = `${title} spostato in ${column}, posizione ${order}.`
  }

  // Dopo lo spostamento il frame dell'item viene rigenerato dal server: riporta
  // il focus sul pulsante "sposta" non appena ricompare, così la navigazione da
  // tastiera resta fluida.
  restoreFocus(frameId) {
    if (!frameId) return

    let attempts = 0
    const tryFocus = () => {
      const frame = document.getElementById(frameId)
      const button = frame?.querySelector('.kanban_controller-move-button')
      if (button instanceof HTMLElement) {
        button.focus()
        return
      }
      if (attempts++ < 30) requestAnimationFrame(tryFocus)
    }
    requestAnimationFrame(tryFocus)
  }

  containerTargetConnected(element) {
    if (!this.dragula) return

    this.dragula.containers.push(element)
  }

  containerTargetDisconnected(element) {
    if (!this.dragula) return

    this.dragula.containers.splice(this.dragula.containers.indexOf(element), 1)
  }
}
