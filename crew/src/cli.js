#!/usr/bin/env node
// matilda-crew CLI: run Claude-powered pseudo-employees against a Matilda instance.
import fs from 'node:fs'
import path from 'node:path'
import { fileURLToPath } from 'node:url'
import { spawn } from 'node:child_process'
import { loadConfig, loadState, writeConfigTemplate, CONFIG_PATH, LOGS_DIR, PID_PATH, DAEMON_LOG_PATH } from './config.js'
import { MatildaClient } from './matilda.js'
import { startLoop } from './loop.js'
import { runAskSession } from './agent.js'

const pkg = JSON.parse(fs.readFileSync(path.join(path.dirname(fileURLToPath(import.meta.url)), '..', 'package.json'), 'utf8'))

const USAGE = `matilda-crew ${pkg.version}

Usage:
  crew init --server <url>   Create config template in ~/.matilda-crew
  crew status                Show employees, their tasks and recent activity
  crew logs <name> [-n 20]   Show an employee's recent activity log
  crew start [--once]        Start the poll loop in foreground (--once = single round)
  crew start --daemon        Start the poll loop in background (logs to ~/.matilda-crew/crew.log)
  crew stop                  Stop the running loop (graceful: finishes work in flight)
  crew restart               Stop the loop and start it again as daemon
  crew ask <name> <question> Ask an employee a one-shot question
  crew update                Check the Matilda server for a newer package and install it
  crew version               Print version
`

function getFlag (args, name) {
  const index = args.indexOf(name)
  if (index === -1) return null
  return args[index + 1] || true
}

function findEmployee (config, name) {
  const employee = config.employees.find((e) => e.name === name)
  if (!employee) throw new Error(`Unknown employee "${name}". Configured: ${config.employees.map((e) => e.name).join(', ')}`)
  return employee
}

const ago = (iso) => {
  if (!iso) return 'never'
  const minutes = Math.round((Date.now() - Date.parse(iso)) / 60000)
  if (minutes < 1) return 'just now'
  if (minutes < 60) return `${minutes}m ago`
  return `${Math.floor(minutes / 60)}h${minutes % 60}m ago`
}

function readLogEntries (name, count) {
  const file = path.join(LOGS_DIR, `${name}.jsonl`)
  if (!fs.existsSync(file)) return []
  const lines = fs.readFileSync(file, 'utf8').trim().split('\n')
  return lines.slice(-count).map((line) => { try { return JSON.parse(line) } catch { return null } }).filter(Boolean)
}

function formatLogEntry (entry) {
  const what = entry.kind === 'error'
    ? `ERROR ${entry.error}`
    : `${entry.kind}${entry.turns ? ` (${entry.turns} turns)` : ''} ${String(entry.result || '').split('\n')[0].slice(0, 120)}`
  const task = entry.task_id ? ` task #${entry.task_id}` : ''
  return `  ${entry.at?.slice(0, 16).replace('T', ' ')}${task}: ${what}`
}

async function cmdStatus () {
  const config = loadConfig()
  const state = loadState()
  console.log(`Server: ${config.server}`)
  const pid = runningPid()
  console.log(`Loop: ${pid ? `running (pid ${pid})` : 'NOT RUNNING — start with: crew start --daemon'}`)

  for (const employee of config.employees) {
    const client = new MatildaClient(config.server, employee.api_key)
    const employeeState = state.employees?.[employee.name] || {}
    let me = null
    let identity = 'NOT REACHABLE'
    try {
      me = await client.me()
      identity = `user #${me.id} ${me.name || me.email || ''}`.trim()
    } catch (err) {
      identity = `ERROR: ${err.message}`
    }

    // A poll older than 2 intervals means no loop is feeding this employee.
    const interval = (employee.poll_interval || 300) * 1000
    const lastPoll = employeeState.last_poll_at
    const stale = !lastPoll || Date.now() - Date.parse(lastPoll) > 2 * interval
    console.log(`\n${employee.name}: ${identity}`)
    console.log(`  last poll: ${ago(lastPoll)}${stale ? ' — LOOP NOT RUNNING? (start with: crew start)' : ''}`)
    console.log(`  instructions: matilda profile description ${me?.description ? 'set' : 'EMPTY'} + local config description ${employee.description ? 'set' : 'EMPTY'}`)

    if (me) {
      // Live view of its plate: what Matilda says is assigned to it right now.
      try {
        const { data: mine } = await client.listTasks({ user_id: me.id, completed: false, per_page: 100 })
        console.log(`  assigned open tasks: ${mine.length}`)
        for (const task of mine) {
          const flag = task.unresolved ? ' [awaiting its reply]' : ''
          console.log(`    #${task.id} ${task.title}${flag}`)
        }
      } catch { /* listing is best-effort, identity errors are already shown */ }
    }

    const entries = readLogEntries(employee.name, 5)
    if (entries.length) {
      console.log('  recent activity (crew logs for more):')
      entries.forEach((entry) => console.log(formatLogEntry(entry)))
    }
  }
}

function cmdLogs (name, args) {
  const config = loadConfig()
  findEmployee(config, name)
  const count = Number(getFlag(args, '-n')) || 20
  const entries = readLogEntries(name, count)
  if (!entries.length) return console.log(`No activity logged yet for "${name}" (${path.join(LOGS_DIR, `${name}.jsonl`)})`)
  entries.forEach((entry) => {
    console.log(formatLogEntry(entry))
    // Full result body, indented, so you can read what the agent actually did.
    const body = String(entry.result || entry.error || '').split('\n').slice(1).join('\n')
    if (body.trim()) console.log(body.replace(/^/gm, '      '))
  })
}

async function cmdAsk (name, question) {
  if (!name || !question) throw new Error('Usage: crew ask <name> <question>')
  const config = loadConfig()
  const employee = findEmployee(config, name)
  const client = new MatildaClient(config.server, employee.api_key)
  const me = await client.me()
  const outcome = await runAskSession(employee, me, client, question, {
    onEvent: (kind, text) => { if (kind === 'tool') console.error(`[${name}:tool] ${text}`) }
  })
  console.log(outcome.result)
}

// Pidfile helpers: the loop process owns the pidfile, `stop` uses it.
function runningPid () {
  if (!fs.existsSync(PID_PATH)) return null
  const pid = Number(fs.readFileSync(PID_PATH, 'utf8'))
  try {
    process.kill(pid, 0)
    return pid
  } catch {
    fs.rmSync(PID_PATH, { force: true }) // stale pidfile
    return null
  }
}

async function cmdStart (args) {
  const config = loadConfig()

  if (args.includes('--daemon')) {
    const existing = runningPid()
    if (existing) throw new Error(`Loop already running (pid ${existing}). Use: crew restart`)
    const out = fs.openSync(DAEMON_LOG_PATH, 'a')
    const child = spawn(process.execPath, [fileURLToPath(import.meta.url), 'start'], {
      detached: true,
      stdio: ['ignore', out, out]
    })
    child.unref()
    console.log(`Loop started in background (pid ${child.pid}). Logs: ${DAEMON_LOG_PATH}`)
    return
  }

  const existing = runningPid()
  if (existing) throw new Error(`Loop already running (pid ${existing}). Use: crew stop`)
  fs.writeFileSync(PID_PATH, String(process.pid))
  process.on('exit', () => { try { fs.rmSync(PID_PATH, { force: true }) } catch {} })
  const log = (message) => console.log(`[${new Date().toISOString().slice(0, 19)}] ${message}`)
  await startLoop(config, { once: args.includes('--once'), log })
}

async function cmdStop ({ quiet = false } = {}) {
  const pid = runningPid()
  if (!pid) {
    if (!quiet) console.log('Loop not running.')
    return false
  }
  process.kill(pid, 'SIGTERM')
  process.stdout.write(`Stopping loop (pid ${pid}), waiting for work in flight...`)
  // Wait up to 3 minutes: an agent session mid-flight is finished, not killed.
  for (let i = 0; i < 180; i++) {
    await new Promise((resolve) => setTimeout(resolve, 1000))
    if (!runningPid()) {
      console.log(' stopped.')
      return true
    }
    if (i % 10 === 9) process.stdout.write('.')
  }
  console.log(`\nStill running after 3 minutes. Force it with: kill -9 ${pid}`)
  return false
}

async function cmdUpdate () {
  const config = loadConfig()
  const res = await fetch(`${config.server.replace(/\/$/, '')}/crew/manifest.json`)
  if (!res.ok) throw new Error(`Cannot fetch manifest from ${config.server}/crew/manifest.json (${res.status}). Has the server published the crew package?`)
  const manifest = await res.json()
  if (manifest.version === pkg.version) {
    console.log(`Already up to date (${pkg.version}).`)
    return
  }
  const url = new URL(manifest.url, config.server).toString()
  console.log(`Updating ${pkg.version} -> ${manifest.version} from ${url}`)
  await new Promise((resolve, reject) => {
    const child = spawn('npm', ['install', '-g', url], { stdio: 'inherit' })
    child.on('exit', (code) => code === 0 ? resolve() : reject(new Error(`npm exited with code ${code}`)))
  })
  console.log('Update installed. Restart `crew start` to use it.')
}

async function main () {
  const [command, ...args] = process.argv.slice(2)

  switch (command) {
    case 'init': {
      const server = getFlag(args, '--server')
      if (!server || server === true) throw new Error('Usage: crew init --server <url>')
      const configPath = writeConfigTemplate(server)
      console.log(`Config template written to ${configPath}`)
      console.log('Edit it: add one entry per employee with its Matilda API key and description.')
      break
    }
    case 'status':
      await cmdStatus()
      break
    case 'logs':
      cmdLogs(args[0], args.slice(1))
      break
    case 'start':
      await cmdStart(args)
      break
    case 'stop':
      await cmdStop()
      break
    case 'restart':
      await cmdStop({ quiet: true })
      await cmdStart(['--daemon'])
      break
    case 'ask':
      await cmdAsk(args[0], args.slice(1).join(' '))
      break
    case 'update':
      await cmdUpdate()
      break
    case 'version':
      console.log(pkg.version)
      break
    default:
      console.log(USAGE)
      if (command) process.exitCode = 1
  }
}

main().catch((err) => {
  console.error(`Error: ${err.message}`)
  if (err.message.includes('Config not found')) console.error(`Expected config at: ${CONFIG_PATH}`)
  process.exitCode = 1
})
