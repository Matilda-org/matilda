import { Controller } from "@hotwired/stimulus"
import Sortable from 'sortablejs'

// Kanban board: drag & drop between/within columns (SortableJS, touch friendly),
// with a keyboard fallback on the move button. The drop is optimistic: SortableJS
// leaves the card where it was dropped and we persist in background; the server
// only re-renders (reverting) when the move fails.
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
    updaterParamOrder: { type: String, default: 'order' },
    // whether items can be reordered within the same column; boards that don't
    // persist an intra-column order (e.g. tasks by date/assignee) set this false
    sort: { type: Boolean, default: true }
  }

  connect() {
    // tracks Sortable instances already destroyed so teardown never double-frees
    this.destroyed = new WeakSet()
    this.sortables = this.containerTargets.map((container) => this.buildSortable(container))

    // scroll arrows are pure manual-scroll helpers now (SortableJS auto-scrolls
    // while dragging): show each one only when the board can scroll that way.
    this.scrollableEl = this.hasScrollableTarget ? this.scrollableTarget : null
    this.onScroll = () => this.updateNav()
    this.scrollableEl?.addEventListener('scroll', this.onScroll, { passive: true })
    window.addEventListener('resize', this.onScroll)
    this.updateNav()
  }

  disconnect() {
    this.sortables?.forEach((sortable) => this.destroySortable(sortable))
    this.sortables = []
    this.scrollableEl?.removeEventListener('scroll', this.onScroll)
    window.removeEventListener('resize', this.onScroll)
  }

  // SortableJS destroy() is not idempotent and throws if the element is already
  // detached (e.g. Turbo navigation tears down disconnect() and every
  // targetDisconnected). Guard so each instance is freed at most once.
  destroySortable(sortable) {
    if (!sortable || this.destroyed.has(sortable)) return
    this.destroyed.add(sortable)
    try {
      sortable.destroy()
    } catch (e) {
      // element already gone during teardown, nothing to clean up
    }
  }

  buildSortable(container) {
    const sortable = Sortable.create(container, {
      group: `kanban-${this.element.dataset.kanbanId || 'default'}`,
      handle: '.kanban_controller-move-button',
      draggable: '[data-item]',
      // when false, dropping in the same column snaps the item back (no reorder),
      // while moving to another column still works
      sort: this.sortValue,
      animation: 150,
      // auto-scroll the horizontal board while dragging near its edges
      scroll: this.scrollableEl || true,
      scrollSensitivity: 80,
      scrollSpeed: 12,
      ghostClass: 'c-kanban__item--ghost',
      chosenClass: 'c-kanban__item--chosen',
      dragClass: 'c-kanban__item--drag',
      onEnd: this.onEnd.bind(this)
    })
    container._kanbanSortable = sortable
    return sortable
  }

  // Guarded so it never throws while the controller is being torn down (target
  // getters raise once their elements have left the DOM).
  updateNav() {
    if (!this.hasScrollableTarget) return

    const el = this.scrollableTarget
    const atStart = el.scrollLeft <= 1
    const atEnd = el.scrollLeft + el.clientWidth >= el.scrollWidth - 1
    if (this.hasPrevTarget) this.prevTarget.classList.toggle('is-visible', !atStart)
    if (this.hasNextTarget) this.nextTarget.classList.toggle('is-visible', !atEnd)
  }

  onEnd(event) {
    // no-op if dropped in the same spot
    if (event.to === event.from && event.oldIndex === event.newIndex) return

    this.commitMove(event.item, event.to, event.newIndex + 1)
  }

  // Newly streamed columns register their container so drag keeps working after
  // a Turbo Stream re-render.
  containerTargetConnected(element) {
    if (!this.sortables) return
    if (element._kanbanSortable) return

    this.sortables.push(this.buildSortable(element))
    requestAnimationFrame(() => this.updateNav())
  }

  containerTargetDisconnected(element) {
    if (element._kanbanSortable) {
      this.destroySortable(element._kanbanSortable)
      this.sortables = this.sortables?.filter((s) => s !== element._kanbanSortable)
      element._kanbanSortable = null
    }
    requestAnimationFrame(() => this.updateNav())
  }

  // Keyboard alternative to drag & drop: with focus on the move button the arrows
  // move the item across columns (left/right) and within the column (up/down).
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
    const siblings = Array.from(currentContainer.querySelectorAll('[data-item]'))
    const currentIndex = siblings.indexOf(itemEl)

    if (direction === 'left' || direction === 'right') {
      const targetContainer = containers[containerIndex + (direction === 'left' ? -1 : 1)]
      if (!targetContainer) return

      const order = targetContainer.querySelectorAll('[data-item]').length + 1
      this.commitMove(itemEl, targetContainer, order)
    } else {
      // up/down reorders within a column; skip on boards that don't persist it
      if (!this.sortValue) return

      const newIndex = currentIndex + (direction === 'up' ? -1 : 1)
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

  // Manual horizontal scroll buttons (also useful outside of a drag).
  scrollPrev() {
    this.scrollableTarget?.scrollBy({ left: -360, behavior: 'smooth' })
  }

  scrollNext() {
    this.scrollableTarget?.scrollBy({ left: 360, behavior: 'smooth' })
  }

  announce(itemEl, containerEl, order) {
    if (!this.hasAnnouncerTarget) return

    const title = itemEl.querySelector('.c-kanban__item-title')?.textContent?.trim() || 'Elemento'
    const column = containerEl.dataset.statusTitle || ''
    this.announcerTarget.textContent = `${title} spostato in ${column}, posizione ${order}.`
  }

  // After a keyboard move the item frame is re-rendered by the server: restore
  // focus on the move button as soon as it reappears, so keyboard navigation
  // stays fluid.
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
}
