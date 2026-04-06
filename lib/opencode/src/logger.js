function log(message) {
  const timestamp = new Date().toISOString()
  console.log(`[${timestamp}] ${message}`)
}

function logError(message) {
  const timestamp = new Date().toISOString()
  console.error(`[${timestamp}] ERROR: ${message}`)
}

function logPhase(phase, message) {
  log(`[${phase.toUpperCase()}] ${message}`)
}

export { log, logError, logPhase }
