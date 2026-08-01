// Config + state live in ~/.matilda-crew so package updates never touch them.
import fs from 'node:fs'
import path from 'node:path'
import os from 'node:os'

// CREW_HOME overrides the state/config location (useful for tests and multi-crew setups).
export const HOME_DIR = process.env.CREW_HOME || path.join(os.homedir(), '.matilda-crew')
export const CONFIG_PATH = path.join(HOME_DIR, 'config.json')
export const STATE_PATH = path.join(HOME_DIR, 'state.json')
export const LOGS_DIR = path.join(HOME_DIR, 'logs')
export const PID_PATH = path.join(HOME_DIR, 'crew.pid')
export const DAEMON_LOG_PATH = path.join(HOME_DIR, 'crew.log')

export const CONFIG_TEMPLATE = {
  server: 'https://matilda.example.com',
  employees: [
    {
      name: 'ada',
      api_key: 'MATILDA_API_KEY_OF_THE_CREW_USER',
      description: 'Junior project assistant: read assigned tasks, do the work you can do with your tools, report results as task comments.',
      poll_interval: 300,
      session_timeout: 30
    }
  ]
}

export function loadConfig () {
  if (!fs.existsSync(CONFIG_PATH)) {
    throw new Error(`Config not found at ${CONFIG_PATH}. Run: crew init --server <url>`)
  }
  const config = JSON.parse(fs.readFileSync(CONFIG_PATH, 'utf8'))
  if (!config.server || !Array.isArray(config.employees)) {
    throw new Error(`Invalid config at ${CONFIG_PATH}: "server" and "employees" are required`)
  }
  return config
}

export function writeConfigTemplate (server) {
  fs.mkdirSync(HOME_DIR, { recursive: true })
  if (fs.existsSync(CONFIG_PATH)) {
    throw new Error(`Config already exists at ${CONFIG_PATH}. Edit it directly.`)
  }
  const config = { ...CONFIG_TEMPLATE, server }
  fs.writeFileSync(CONFIG_PATH, JSON.stringify(config, null, 2) + '\n')
  return CONFIG_PATH
}

// State: { employees: { [name]: { last_poll_at, tasks: { [id]: { handled_at, updated_at } } } } }
export function loadState () {
  if (!fs.existsSync(STATE_PATH)) return { employees: {} }
  return JSON.parse(fs.readFileSync(STATE_PATH, 'utf8'))
}

export function saveState (state) {
  fs.mkdirSync(HOME_DIR, { recursive: true })
  fs.writeFileSync(STATE_PATH, JSON.stringify(state, null, 2) + '\n')
}

// Live marker of the session in flight, so `crew status` can show real work.
// Guarded by the loop's pid: a marker left by a crashed process is ignored.
export const ACTIVITY_PATH = path.join(HOME_DIR, 'activity.json')

export function setActivity (data) {
  if (!data) {
    fs.rmSync(ACTIVITY_PATH, { force: true })
    return
  }
  fs.mkdirSync(HOME_DIR, { recursive: true })
  fs.writeFileSync(ACTIVITY_PATH, JSON.stringify({ ...data, pid: process.pid }))
}

export function getActivity () {
  if (!fs.existsSync(ACTIVITY_PATH)) return null
  try {
    const activity = JSON.parse(fs.readFileSync(ACTIVITY_PATH, 'utf8'))
    process.kill(activity.pid, 0) // throws if the loop died mid-session
    return activity
  } catch {
    return null
  }
}

// Append a JSONL entry to the employee's activity log.
export function appendLog (employeeName, entry) {
  fs.mkdirSync(LOGS_DIR, { recursive: true })
  const line = JSON.stringify({ at: new Date().toISOString(), ...entry })
  fs.appendFileSync(path.join(LOGS_DIR, `${employeeName}.jsonl`), line + '\n')
}
