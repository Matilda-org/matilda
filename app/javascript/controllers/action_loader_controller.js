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
 *
 * It also owns the modal lifecycle shared by every action:
 * - a page opened with ?modal=<path> (see action_controller#mirrorUrl) reopens it;
 * - clicking the backdrop closes the modal until a form inside it is edited,
 *   then the backdrop turns static so typed data is never lost by a stray click.
 */
export default class extends Controller {
  connect() {
    this.frame = this.element.querySelector('#action')
    if (!this.frame) return

    this.onFetchStart = this.onFetchStart.bind(this)
    this.onFormEdit = this.onFormEdit.bind(this)
    this.onHide = this.onHide.bind(this)
    this.onHidden = this.onHidden.bind(this)

    this.frame.addEventListener('turbo:before-fetch-request', this.onFetchStart)
    this.element.addEventListener('input', this.onFormEdit)
    this.element.addEventListener('trix-change', this.onFormEdit)
    this.element.addEventListener('hide.bs.modal', this.onHide)
    this.element.addEventListener('hidden.bs.modal', this.onHidden)

    this.openFromUrl()
  }

  disconnect() {
    if (!this.frame) return

    this.frame.removeEventListener('turbo:before-fetch-request', this.onFetchStart)
    this.element.removeEventListener('input', this.onFormEdit)
    this.element.removeEventListener('trix-change', this.onFormEdit)
    this.element.removeEventListener('hide.bs.modal', this.onHide)
    this.element.removeEventListener('hidden.bs.modal', this.onHidden)
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

    this.modal.show()
  }

  // Only same-origin action endpoints: the param must never point the frame elsewhere
  openFromUrl() {
    const path = new URL(window.location).searchParams.get('modal')
    if (!path) return

    const target = new URL(path, window.location.origin)
    if (target.origin !== window.location.origin || !/^\/[a-z-]+\/actions\//.test(target.pathname)) return

    this.frame.src = target.pathname + target.search
  }

  onFormEdit(event) {
    if (!event.target.closest('form')) return

    // Bootstrap reads the config on every backdrop click, so switching it live works
    this.modal._config.backdrop = 'static'
  }

  onHide() {
    const url = new URL(window.location)
    if (!url.searchParams.has('modal')) return

    url.searchParams.delete('modal')
    window.history.replaceState(window.history.state, '', url)
  }

  onHidden() {
    this.modal._config.backdrop = true
  }

  get modal() {
    return bootstrap.Modal.getOrCreateInstance(this.element)
  }
}
