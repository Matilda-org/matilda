import { Controller } from '@hotwired/stimulus'

// Keeps a long comment thread readable: opens already scrolled on the newest
// comment, offers a jump-to-latest shortcut while reading older ones, and lets
// collapsed long bodies expand on demand.
export default class extends Controller {
  static targets = ['thread', 'jump', 'body']

  connect () {
    this.landed = false
    this.resolveClamps()

    // The thread has no layout while the card is collapsed or the modal is still
    // animating: re-run clamping and the initial jump once it gets measured.
    this.observer = new window.ResizeObserver(() => {
      this.resolveClamps()
      if (!this.landed) this.scrollToLatest(null, false)
    })
    this.observer.observe(this.element)

    // Wait a frame so clamping has settled before measuring the scroll height.
    window.requestAnimationFrame(() => this.scrollToLatest(null, false))
  }

  disconnect () {
    if (this.observer) this.observer.disconnect()
  }

  // The server collapses bodies by character count, which over-triggers on short
  // wide text: drop the clamp when the rendered body doesn't actually overflow.
  resolveClamps () {
    this.bodyTargets.forEach(body => {
      if (body.dataset.clampResolved) return
      if (!body.classList.contains('c-comment__body--clamped')) return
      if (!body.clientHeight) return

      body.dataset.clampResolved = '1'

      const toggle = this.toggleFor(body)
      if (!toggle) return

      if (body.scrollHeight - body.clientHeight < 8) {
        body.classList.remove('c-comment__body--clamped')
        toggle.remove()
      } else {
        toggle.classList.remove('d-none')
      }
    })
  }

  toggleBody (event) {
    event.preventDefault()

    const toggle = event.currentTarget
    const body = toggle.parentElement.querySelector('[data-comments-target="body"]')
    if (!body) return

    const clamped = body.classList.toggle('c-comment__body--clamped')
    toggle.textContent = clamped ? 'Mostra tutto' : 'Riduci'
  }

  scrollToLatest (event = null, smooth = true) {
    if (event) event.preventDefault()
    if (!this.hasThreadTarget) return

    const thread = this.threadTarget
    if (!thread.scrollHeight) return // no layout yet: the resize observer retries

    thread.scrollTo({ top: thread.scrollHeight, behavior: smooth ? 'smooth' : 'auto' })
    this.landed = true
    this.updateJump()
  }

  // The shortcut only makes sense once the newest comment is off-screen.
  updateJump () {
    if (!this.hasJumpTarget || !this.hasThreadTarget) return

    const thread = this.threadTarget
    const distanceFromBottom = thread.scrollHeight - thread.scrollTop - thread.clientHeight
    this.jumpTarget.classList.toggle('d-none', distanceFromBottom < 80)
  }

  toggleFor (body) {
    return body.parentElement.querySelector('[data-comments-toggle]')
  }
}
