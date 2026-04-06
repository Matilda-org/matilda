import path from "node:path"
import { fileURLToPath } from "node:url"
import { Worker } from "node:worker_threads"
import { logPhase, logError } from "./logger.js"

const __dirname = path.dirname(fileURLToPath(import.meta.url))

function startWorker(name, file) {
  const worker = new Worker(path.join(__dirname, "workers", file))
  worker.on("error", (err) => logError(`[${name}] ${err.message}`))
  worker.on("exit", (code) => {
    if (code !== 0) logError(`[${name}] exited with code ${code}`)
  })
  logPhase("main", `Started worker: ${name}`)
  return worker
}

startWorker("ping", "ping.js")
startWorker("orchestrator", "orchestrator.js")
