import { Controller } from "@hotwired/stimulus"
import dragula from 'dragula'
// import { debounce } from 'libs/utils'

export default class extends Controller {
  static targets = [
    'container',
    'prev',
    'next',
    'scrollable'
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
    const item = el.dataset.item
    const container = target.dataset.container
    const order = Array.from(target.children).indexOf(el) + 1
    const updater = el.querySelector('.kanban_controller-item-updater')
    if (!updater) return

    const updaterUrl = new URL(updater.href)
    updaterUrl.searchParams.set(this.updaterParamContainerValue, container)
    updaterUrl.searchParams.set(this.updaterParamItemValue, item)
    updaterUrl.searchParams.set(this.updaterParamOrderValue, order)
    updater.href = updaterUrl.href

    updater.click()
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
