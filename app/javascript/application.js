import "@hotwired/turbo-rails"
import "bootstrap"
import "trix"
import "@rails/actiontext"
import "controllers"

window.env = document.querySelector("meta[name='env']")?.content
window.process = { env: { NODE_ENV: window.env } }

/**
 * Service worker
 */

if (navigator.serviceWorker && window.env === 'production') {
  window.addEventListener('load', () => {
    // navigator.serviceWorker.getRegistrations().then(function(registrations) {
    //   for(let registration of registrations) {
    //     registration.unregister()
    //   }
    // })
    navigator.serviceWorker.register('/service-worker.js').then(function(reg) {
      console.log('[Page] Service worker registered!')
    })
  })
}

/**
 * Clean pages before cache
 */

document.addEventListener('turbo:before-cache', (e) => {
  e.preventDefault()

  // hide modals and make body scrollable
  document.querySelectorAll('.modal.show').forEach((el) => {
    el.classList.remove('show')
    el.style.display = 'none'
  })
  document.querySelectorAll('.modal-backdrop').forEach((el) => {
    el.remove()
  })
  document.body.classList.remove('modal-open')
  document.body.style.paddingRight = ''
  document.body.style.overflow = ''

  // hide tooltips
  document.querySelectorAll('.tooltip').forEach((el) => {
    el.remove()
  })

  // close mobile menu
  document.querySelector('.navbar-toggler').classList.add('collapsed')
  document.querySelector('.navbar-collapse').classList.remove('show')

  // remove all .turbo-before-cache-clean
  document.querySelectorAll('.turbo-before-cache-clean').forEach((el) => {
    el.remove()
  })

  e.detail?.resume()
})

/**
 * Reload page on resize
 */

let resizeTimeout
let resizeLastWidth = window.innerWidth
window.addEventListener('resize', function(event) {
  clearTimeout(resizeTimeout)
  resizeTimeout = setTimeout(function(){
    const currentWidth = window.innerWidth
    const diffWidth = Math.abs(resizeLastWidth - currentWidth)
    resizeLastWidth = currentWidth
    if (diffWidth > 100) {
      window.location.reload()
    }
  }, 500)
})

/**
 * HACK: Preserve horizontal scroll position on turbo frame update for kanban boards
 */

let horizontalScrollPositionsKanbanBoards = {};

document.addEventListener('turbo:before-fetch-request', (event) => {
  const href = event.target.getAttribute('href')
  if (!href) return

  const hrefParams = new URL(href, window.location.origin).searchParams
  const turboFrameKey = hrefParams.get('turbo_frame_key')
  if (!turboFrameKey) return

  const frame = document.getElementById(turboFrameKey)
  if (!frame) return

  const scrollableElement = frame.querySelector('.c-kanban__scrollable')
  if (!scrollableElement) return
  
  horizontalScrollPositionsKanbanBoards[turboFrameKey] = scrollableElement.scrollLeft;
});

document.addEventListener('turbo:frame-load', (event) => {
  const frame = event.target;
  if (!frame) return;

  const scrollableElement = frame.querySelector('.c-kanban__scrollable')
  if (!scrollableElement) return;

  const savedPosition = horizontalScrollPositionsKanbanBoards[frame.id];
  if (!savedPosition) return;

  scrollableElement.scrollLeft = savedPosition;
  delete horizontalScrollPositionsKanbanBoards[frame.id];
});