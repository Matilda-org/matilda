import { Controller } from '@hotwired/stimulus'

/**
 * action-loader
 *
 * Gives immediate feedback when opening the shared `action` modal.
 *
 * The `action` turbo-frame lives inside a hidden Bootstrap modal: until the
 * server response arrives and `action_controller` shows the modal, clicking an
 * action (edit, new, delete confirm, show, ...) produces no visible feedback.
 *
 * As soon as a request targeting the frame starts, this controller shows the
 * modal with a spinner. When the response replaces the frame content, the real
 * dialog takes over (`action_controller#connect` re-shows the modal, idempotent).
 *
 * Submits that happen while the modal is already open are left untouched, so the
 * existing form-loading button spinner keeps handling that case.
 */
export default class extends Controller {
  connect() {
    this.frame = this.element.querySelector('#action')
    if (!this.frame) return

    this.onFetchStart = this.onFetchStart.bind(this)
    this.frame.addEventListener('turbo:before-fetch-request', this.onFetchStart)
  }

  disconnect() {
    if (this.frame) this.frame.removeEventListener('turbo:before-fetch-request', this.onFetchStart)
  }

  onFetchStart() {
    // Modal already open => navigation/submit inside the modal; let the form
    // button spinner handle feedback and keep the current content visible.
    if (this.element.classList.contains('show')) return

    this.frame.innerHTML = `
      <div class="modal-dialog modal-dialog-centered">
        <div class="modal-content">
          <div class="d-flex justify-content-center align-items-center p-5">
            <div class="spinner-border text-primary" role="status">
              <span class="visually-hidden">Caricamento…</span>
            </div>
          </div>
        </div>
      </div>`

    bootstrap.Modal.getOrCreateInstance(this.element).show()
  }
}
