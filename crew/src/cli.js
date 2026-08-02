#!/usr/bin/env node
// matilda-crew CLI: run Claude-powered pseudo-employees against a Matilda instance.
import fs from 'node:fs'
import path from 'node:path'
import { fileURLToPath } from 'node:url'
import { spawn, execFileSync } from 'node:child_process'
import { loadConfig, loadState, writeConfigTemplate, getActivity, CONFIG_PATH, LOGS_DIR, PID_PATH, DAEMON_LOG_PATH, STOPPING_PATH } from './config.js'
import { MatildaClient } from './matilda.js'
import { startLoop } from './loop.js'
import { runAskSession, runChatTurn } from './agent.js'
import readline from 'node:readline/promises'

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
  crew chat [name]           Interactive chat with an employee (default: the first one)
  crew menubar               Print current state in SwiftBar/xbar plugin format
  crew menubar --install     Install the SwiftBar/xbar menu bar plugin
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
    const activity = getActivity()
    if (activity?.employee === employee.name) {
      console.log(`  >>> WORKING NOW on task #${activity.task_id} "${activity.task_title}" (started ${ago(activity.started_at)})`)
    }
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
  fs.rmSync(STOPPING_PATH, { force: true }) // stale marker from a force kill
  process.on('exit', () => {
    try {
      fs.rmSync(PID_PATH, { force: true })
      fs.rmSync(STOPPING_PATH, { force: true })
    } catch {}
  })
  const log = (message) => console.log(`[${new Date().toISOString().slice(0, 19)}] ${message}`)
  await startLoop(config, { once: args.includes('--once'), log })
}

async function cmdStop ({ quiet = false, wait = true } = {}) {
  const pid = runningPid()
  if (!pid) {
    if (!quiet) console.log('Loop not running.')
    return false
  }
  process.kill(pid, 'SIGTERM')
  if (!wait) {
    console.log(`Stop signal sent to pid ${pid}: it exits when work in flight is done.`)
    return true
  }
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

// Interactive chat: multi-turn REPL with SDK session continuity.
async function cmdChat (name) {
  const config = loadConfig()
  const employee = name ? findEmployee(config, name) : config.employees[0]
  const client = new MatildaClient(config.server, employee.api_key)
  const me = await client.me()
  console.log(`Chat con ${employee.name} (${config.server}) — /exit per uscire\n`)

  // Piped stdin (scripting): read every line upfront — readline would lose
  // buffered lines while a turn is in flight. TTY: normal interactive REPL.
  let nextLine
  let rl = null
  if (process.stdin.isTTY) {
    rl = readline.createInterface({ input: process.stdin, output: process.stdout })
    rl.on('SIGINT', () => { rl.close(); process.exit(0) })
    nextLine = () => rl.question('tu> ')
  } else {
    const lines = fs.readFileSync(0, 'utf8').split('\n')
    nextLine = async () => lines.length ? lines.shift() : '/exit'
  }

  let sessionId = null
  while (true) {
    const text = (await nextLine()).trim()
    if (!text) continue
    if (text === '/exit') break
    if (!process.stdin.isTTY) console.log(`tu> ${text}`)
    try {
      const outcome = await runChatTurn(employee, me, client, text, {
        sessionId,
        onEvent: (kind, detail) => { if (kind === 'tool') console.log(`  ⚙︎ ${detail.slice(0, 120)}`) }
      })
      sessionId = outcome.session_id || sessionId
      console.log(`\n${employee.name}> ${outcome.result}\n`)
    } catch (err) {
      console.error(`Errore: ${err.message}`)
    }
  }
  rl?.close()
}

// SwiftBar/xbar plugin output: menu bar title, then dropdown lines.
// Reads only local files (pid, activity, state, logs) — safe at short refresh.
function cmdMenubar (args) {
  if (args.includes('--install')) return installMenubar()

  const clean = (text) => String(text).replace(/\|/g, '∣').replace(/\n/g, ' ')
  const action = (label, ...params) =>
    `${label} | bash=${process.execPath} param1=${fileURLToPath(import.meta.url)} ${params.map((p, i) => `param${i + 2}=${p}`).join(' ')} terminal=false refresh=true`

  let config = null
  try { config = loadConfig() } catch {}
  const pid = runningPid()
  const stopping = pid && fs.existsSync(STOPPING_PATH)
  const activity = pid ? getActivity() : null
  const state = loadState()

  // Menu bar title
  if (!config || !pid) console.log('⚫️ crew')
  else if (stopping) console.log('🟠 crew')
  else if (activity) console.log(`🔵 #${activity.task_id}`)
  else console.log('🟢 crew')
  console.log('---')

  if (!config) {
    console.log('Crew not configured | color=red')
    console.log(`Run: crew init --server <url> | font=Menlo size=11`)
    return
  }

  if (stopping) console.log('Stopping — finishing work in flight… | color=orange')
  else console.log(pid ? `Loop running (pid ${pid}) | color=green` : 'Loop stopped | color=red')
  if (activity) {
    console.log(`⚙️ ${activity.employee} on #${activity.task_id} (${ago(activity.started_at)})`)
    console.log(`-- ${clean(activity.task_title)} | length=70`)
  }
  console.log('---')

  for (const employee of config.employees) {
    const employeeState = state.employees?.[employee.name] || {}
    const tracked = Object.keys(employeeState.tasks || {}).length
    console.log(`${employee.name} — last poll ${ago(employeeState.last_poll_at)}, ${tracked} tracked tasks`)
    for (const entry of readLogEntries(employee.name, 3).reverse()) {
      const line = entry.kind === 'error'
        ? `❌ #${entry.task_id} ${clean(entry.error)}`
        : `✔︎ #${entry.task_id || '-'} ${clean(String(entry.result || '').split('\n')[0])}`
      console.log(`-- ${entry.at?.slice(11, 16)} ${line} | length=80 font=Menlo size=11`)
    }
  }
  console.log('---')

  console.log(`Apri Matilda | href=${config.server}`)
  console.log(`💬 Chat con la crew | bash=${process.execPath} param1=${fileURLToPath(import.meta.url)} param2=chat terminal=true`)
  if (pid && !stopping) {
    console.log(action('🛑 Stop loop', 'stop', '--no-wait'))
    console.log(action('🔄 Restart loop', 'restart'))
  } else if (!pid) {
    console.log(action('▶️ Start loop', 'start', '--daemon'))
  }
}

// Install the plugin into the SwiftBar (or xbar) plugin directory.
function installMenubar () {
  let dir = null
  try {
    dir = execFileSync('defaults', ['read', 'com.ameba.SwiftBar', 'PluginDirectory'], { encoding: 'utf8' }).trim()
  } catch {}
  if (!dir) {
    const xbarDir = path.join(process.env.HOME || '', 'Library/Application Support/xbar/plugins')
    if (fs.existsSync(xbarDir)) dir = xbarDir
  }
  if (!dir || !fs.existsSync(dir)) {
    throw new Error('No SwiftBar/xbar plugin directory found. Install one first: brew install swiftbar (then launch it once) — or brew install xbar.')
  }

  const plugin = path.join(dir, 'crew.5s.sh')
  fs.writeFileSync(plugin, `#!/bin/bash\nexec "${process.execPath}" "${fileURLToPath(import.meta.url)}" menubar\n`, { mode: 0o755 })
  console.log(`Plugin installed: ${plugin}`)
  console.log('It refreshes every 5 seconds. Rename the file (e.g. crew.30s.sh) to change the interval.')
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
      await cmdStop({ wait: !args.includes('--no-wait') })
      break
    case 'restart':
      await cmdStop({ quiet: true })
      await cmdStart(['--daemon'])
      break
    case 'ask':
      await cmdAsk(args[0], args.slice(1).join(' '))
      break
    case 'chat':
      await cmdChat(args[0])
      break
    case 'menubar':
      cmdMenubar(args)
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

// Piping into `head` etc. must not crash the CLI.
process.stdout.on('error', (err) => { if (err.code === 'EPIPE') process.exit(0) })

main().catch((err) => {
  console.error(`Error: ${err.message}`)
  if (err.message.includes('Config not found')) console.error(`Expected config at: ${CONFIG_PATH}`)
  process.exitCode = 1
})
