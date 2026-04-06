import { createOpencode } from "@opencode-ai/sdk"
import { logPhase } from "./logger.js"

let _instance = null

/**
 * Get or create a singleton opencode client/server instance.
 */
async function getInstance() {
  if (!_instance) {
    logPhase("opencode", "Starting opencode server...")
    _instance = await createOpencode({ config: {} })
    logPhase("opencode", "Opencode server started")
  }
  return _instance
}

/**
 * Close the opencode server if running.
 */
function close() {
  if (_instance) {
    _instance.server.close()
    _instance = null
  }
}

/**
 * Create a session and send a prompt, streaming output in real-time.
 *
 * @param {object} options
 * @param {string} options.title - Session title
 * @param {string} options.prompt - The prompt text to send
 * @param {string} [options.sessionId] - Existing session ID to reuse (skip creation)
 * @param {string} [options.directory] - Working directory for the session
 * @param {(delta: string) => void} [options.onText] - Callback for each text delta
 * @returns {Promise<{ sessionId: string, parts: Array, text: string }>}
 */
async function prompt({ title, prompt: promptText, sessionId, directory, onText }) {
  const { client } = await getInstance()

  const dirQuery = directory ? { directory } : undefined

  // Create session if not provided
  if (!sessionId) {
    const session = await client.session.create({ body: { title }, query: dirQuery })
    sessionId = session.data.id
    logPhase("opencode", `Session created: ${sessionId} - ${title}`)
  }

  // Subscribe to global events BEFORE sending the prompt
  const eventStream = await client.global.event()

  // Send prompt async (returns immediately)
  await client.session.promptAsync({
    path: { id: sessionId },
    body: {
      parts: [{ type: "text", text: promptText }]
    },
    query: dirQuery
  })

  logPhase("opencode", `Prompt sent to session ${sessionId}`)

  // Consume the event stream until the session goes idle
  let collectedText = ""
  const textPartIds = new Set()

  for await (const event of eventStream.stream) {
    const ev = event?.payload || event
    if (!ev || !ev.type) continue
    if (ev.properties?.sessionID !== sessionId) continue

    // Track which parts are text type
    if (ev.type === "message.part.updated") {
      const { part } = ev.properties
      if (part.type === "text") textPartIds.add(part.id)
    }

    // Stream text deltas in real-time
    if (ev.type === "message.part.delta") {
      const { partID, field, delta } = ev.properties
      if (field === "text" && delta && textPartIds.has(partID)) {
        collectedText += delta
        if (onText) {
          onText(delta)
        } else {
          process.stdout.write(delta)
        }
      }
    }

    if (ev.type === "session.idle") break

    if (ev.type === "session.error") {
      logPhase("opencode", `Session error: ${JSON.stringify(ev.properties)}`)
      break
    }
  }

  logPhase("opencode", `Session ${sessionId} completed, text: ${collectedText.slice(0, 100)}`)

  return {
    sessionId,
    text: collectedText,
  }
}

export { getInstance, close, prompt }
