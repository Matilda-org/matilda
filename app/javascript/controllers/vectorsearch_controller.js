import { Controller } from '@hotwired/stimulus'

const TEXTAREA_MAX_HEIGHT = 160

// Assistant chat panel. The answer is computed inside the send request (it can
// take a while), and the chat frame is refreshed by Action Cable broadcasts.
// Meanwhile the panel shows the message right away with a typing indicator,
// locks the composer to avoid double sends and offers a retry on failure.
export default class extends Controller {
  static targets = [
    'content',
    'background',
    'chat',
    'form',
    'submit',
    'textarea',
    'text',
    'typing'
  ]

  chatTargetConnected (chat) {
    // the server renders UTC (no app time zone): show the viewer's local time
    chat.querySelectorAll('time[datetime]').forEach((time) => {
      time.textContent = new Date(time.dateTime).toLocaleTimeString('it-IT', { hour: '2-digit', minute: '2-digit' })
    })
    this.scrollToBottom()
  }

  // Links in answers: app paths navigate the page, anything else opens a new tab
  textTargetConnected (element) {
    element.querySelectorAll('a[href]').forEach((link) => {
      const url = new URL(link.getAttribute('href'), window.location.origin)
      if (url.origin === window.location.origin) {
        link.dataset.turboFrame = '_top'
      } else {
        link.target = '_blank'
        link.rel = 'noopener noreferrer'
      }
    })
  }

  textareaTargetConnected () {
    this.resize()
    if (this.isOpen) this.textareaTarget.focus()
  }

  open (e) {
    e?.preventDefault()

    this.contentTarget.classList.add('is-open')
    this.backgroundTarget.classList.add('is-open')
    this.scrollToBottom()
    if (this.hasTextareaTarget) this.textareaTarget.focus()
  }

  close (e) {
    if (!this.isOpen) return
    e?.preventDefault()

    this.contentTarget.classList.remove('is-open')
    this.backgroundTarget.classList.remove('is-open')
  }

  keydown (e) {
    if (e.key !== 'Enter' || e.shiftKey || e.isComposing) return

    e.preventDefault()
    if (!this.submitTarget.disabled) this.formTarget.requestSubmit()
  }

  // Auto-grow up to a few lines; the send button follows the content
  resize () {
    const textarea = this.textareaTarget
    textarea.style.height = 'auto'
    textarea.style.height = `${Math.min(textarea.scrollHeight, TEXTAREA_MAX_HEIGHT)}px`
    textarea.style.overflowY = textarea.scrollHeight > TEXTAREA_MAX_HEIGHT ? 'auto' : 'hidden'
    if (!this.sending) this.submitTarget.disabled = textarea.value.trim() === ''
  }

  suggest ({ params: { text } }) {
    if (!this.hasTextareaTarget || this.sending) return

    this.textareaTarget.value = text
    this.resize()
    this.formTarget.requestSubmit()
  }

  submitStart (e) {
    if (e.target !== this.formTarget) return

    const text = this.textareaTarget.value.trim()
    if (text === '') {
      e.detail.formSubmission.stop()
      return
    }

    this.sending = true
    this.lastText = text
    this.formTarget.classList.add('is-sending')
    this.submitTarget.disabled = true
    // readonly, not disabled: a disabled field would be left out of the request
    this.textareaTarget.readOnly = true

    // the request body is already built: the composer can be emptied right away
    this.textareaTarget.value = ''
    this.resize()

    this.removeError()
    this.appendUserMessage(text)
    this.appendTyping()
  }

  // A failed send must not render: an error page has no composer frame and
  // Turbo would leave the page. submitEnd then shows the retry.
  beforeFetchResponse (e) {
    if (e.target !== this.formTarget || e.detail.fetchResponse.succeeded) return

    e.preventDefault()
  }

  submitEnd (e) {
    if (e.target !== this.formTarget) return

    this.sending = false
    if (e.detail.success) {
      // The response re-renders an empty composer; reload the chat too, in
      // case the broadcast with the answer was lost (Action Cable offline)
      this.chatTarget.closest('turbo-frame')?.reload()
      return
    }

    this.formTarget.classList.remove('is-sending')
    this.textareaTarget.readOnly = false
    this.resize()
    this.typingTargets.forEach((typing) => typing.remove())
    this.appendError()
  }

  retry () {
    this.removeError()
    // the failed bubble: submitStart adds it again
    this.chatTarget.querySelectorAll('[data-optimistic]').forEach((row) => row.remove())
    this.textareaTarget.value = this.lastText || ''
    this.resize()
    this.formTarget.requestSubmit()
  }

  async copy (e) {
    const button = e.currentTarget
    const text = button.closest('.vectorsearch__chat-row')?.querySelector('.vectorsearch__chat-text')?.innerText || ''

    try {
      await navigator.clipboard.writeText(text.trim())
      button.querySelector('i').className = 'bi bi-clipboard-check'
      button.setAttribute('aria-label', 'Copiato')
      setTimeout(() => {
        button.querySelector('i').className = 'bi bi-clipboard'
        button.setAttribute('aria-label', 'Copia risposta')
      }, 1500)
    } catch {
      button.querySelector('i').className = 'bi bi-clipboard-x'
    }
  }

  // Optimistic bubbles: replaced by the broadcast of the real chat

  appendUserMessage (text) {
    this.chatTarget.querySelector('.vectorsearch__chat-empty')?.remove()

    const row = this.buildRow('user')
    row.dataset.optimistic = 'true'
    const bubble = row.querySelector('.vectorsearch__chat-text')
    bubble.textContent = text
    this.chatTarget.appendChild(row)
    this.scrollToBottom()
  }

  appendTyping () {
    if (this.hasTypingTarget) return

    const row = this.buildRow('assistant')
    row.dataset.vectorsearchTarget = 'typing'
    const bubble = row.querySelector('.vectorsearch__chat-message')
    bubble.classList.add('vectorsearch__chat-typing')
    bubble.setAttribute('role', 'status')
    bubble.innerHTML = '<span class="vectorsearch__chat-dots" aria-hidden="true"><span></span><span></span><span></span></span><span class="visually-hidden">L\'assistente sta scrivendo…</span>'
    this.chatTarget.appendChild(row)
    this.scrollToBottom()
  }

  appendError () {
    const row = this.buildRow('assistant')
    row.classList.add('vectorsearch__chat-row--error')
    const bubble = row.querySelector('.vectorsearch__chat-message')
    bubble.classList.add('vectorsearch__chat-message--error')
    bubble.setAttribute('role', 'alert')
    bubble.innerHTML = '<div class="vectorsearch__chat-text"><i class="bi bi-exclamation-triangle-fill me-1"></i> Messaggio non inviato: controlla la connessione.</div>'

    const button = document.createElement('button')
    button.type = 'button'
    button.className = 'btn btn-sm btn-outline-danger mt-2'
    button.dataset.action = 'vectorsearch#retry'
    button.innerHTML = '<i class="bi bi-arrow-clockwise"></i> Riprova'
    bubble.appendChild(button)

    this.chatTarget.appendChild(row)
    this.scrollToBottom()
  }

  removeError () {
    this.chatTarget.querySelectorAll('.vectorsearch__chat-row--error').forEach((row) => row.remove())
  }

  buildRow (role) {
    const row = document.createElement('div')
    row.className = `vectorsearch__chat-row vectorsearch__chat-row--${role}`
    row.innerHTML = `<div class="vectorsearch__chat-message vectorsearch__chat-message--${role}"><div class="vectorsearch__chat-text"></div></div>`
    return row
  }

  scrollToBottom () {
    if (!this.hasChatTarget) return

    requestAnimationFrame(() => {
      this.chatTarget.scrollTop = this.chatTarget.scrollHeight
    })
  }

  get isOpen () {
    return this.contentTarget.classList.contains('is-open')
  }
}
