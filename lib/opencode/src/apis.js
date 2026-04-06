import http from "node:http"
import https from "node:https"
import { createRequire } from "node:module"
import { hostname } from "node:os"
import { log, logError } from "./logger.js"

const require = createRequire(import.meta.url)
const config = require('../config.json')
const machine = hostname()

function apiRequest(method, apiPath, body = null) {
  return new Promise((resolve, reject) => {
    const url = new URL(apiPath, config.matilda_api_url)
    const isHttps = url.protocol === "https:"
    const transport = isHttps ? https : http

    const options = {
      hostname: url.hostname,
      port: url.port || (isHttps ? 443 : 80),
      path: url.pathname + url.search,
      method,
      headers: {
        "X-API-Key": config.matilda_api_key,
        "Content-Type": "application/json",
      },
    }

    const req = transport.request(options, (res) => {
      let data = ""
      res.on("data", (chunk) => (data += chunk))
      res.on("end", () => {
        try {
          resolve({ status: res.statusCode, data: data ? JSON.parse(data) : null })
        } catch {
          resolve({ status: res.statusCode, data })
        }
      })
    })

    req.on("error", reject)

    if (body) {
      req.write(JSON.stringify(body))
    }

    req.end()
  })
}

async function ping() {
  try {
    await apiRequest("POST", "/apis/opencode-integration/ping", { machine })
    log("Ping sent successfully")
  } catch (err) {
    logError(`Ping failed: ${err.message}`)
  }
}

async function fetchTasks() {
  try {
    const res = await apiRequest(
      "GET",
      "/apis/tasks?completed=false&opencode_assignment=true"
    )
    if (res.status === 200 && Array.isArray(res.data)) {
      return res.data
    }
    logError(`Failed to fetch tasks: status ${res.status}`)
    return []
  } catch (err) {
    logError(`Failed to fetch tasks: ${err.message}`)
    return []
  }
}

async function fetchTaskDetails(taskId) {
  try {
    const res = await apiRequest("GET", `/apis/tasks/${taskId}`)
    if (res.status === 200 && res.data) {
      return res.data
    }
    logError(`Failed to fetch task ${taskId}: status ${res.status}`)
    return null
  } catch (err) {
    logError(`Failed to fetch task ${taskId}: ${err.message}`)
    return null
  }
}

async function postComment(taskId, content) {
  try {
    const res = await apiRequest("POST", `/apis/tasks/${taskId}/comment`, {
      service: "OpenCode",
      content,
    })
    if (res.status >= 200 && res.status < 300) {
      log(`Comment posted on task ${taskId}`)
      return true
    }
    logError(`Failed to post comment on task ${taskId}: status ${res.status}`)
    return false
  } catch (err) {
    logError(`Failed to post comment on task ${taskId}: ${err.message}`)
    return false
  }
}

export { apiRequest, ping, fetchTasks, fetchTaskDetails, postComment }
