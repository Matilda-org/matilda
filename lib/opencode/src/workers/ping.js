import { parentPort } from "node:worker_threads"
import { ping } from "../apis.js"
import { logPhase } from "../logger.js"

const INTERVAL_MS = 60_000

async function run() {
  logPhase("ping", "Worker started")
  await ping()

  setInterval(async () => {
    await ping()
  }, INTERVAL_MS)
}

run()
