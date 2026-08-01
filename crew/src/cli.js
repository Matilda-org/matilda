#!/usr/bin/env node
// matilda-crew CLI: run Claude-powered pseudo-employees against a Matilda instance.
import fs from 'node:fs'
import path from 'node:path'
import { fileURLToPath } from 'node:url'
import { spawn } from 'node:child_process'
import { loadConfig, loadState, writeConfigTemplate, CONFIG_PATH } from './config.js'
import { MatildaClient } from './matilda.js'
import { startLoop } from './loop.js'
import { runAskSession } from './agent.js'

const pkg = JSON.parse(fs.readFileSync(path.join(path.dirname(fileURLToPath(import.meta.url)), '..', 'package.json'), 'utf8'))

const USAGE = `matilda-crew ${pkg.version}

Usage:
  crew init --server <url>   Create config template in ~/.matilda-crew
  crew status                Show employees and their state
  crew start [--once]        Start the poll loop (--once = single round)
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

async function cmdStatus () {
  const config = loadConfig()
  const state = loadState()
  console.log(`Server: ${config.server}`)
  for (const employee of config.employees) {
    const client = new MatildaClient(config.server, employee.api_key)
    let identity = 'NOT REACHABLE'
    try {
      const me = await client.me()
      identity = `user #${me.id} ${me.name || me.email || ''}`.trim()
    } catch (err) {
      identity = `ERROR: ${err.message}`
    }
    const employeeState = state.employees?.[employee.name]
    const openTasks = employeeState ? Object.keys(employeeState.tasks || {}).length : 0
    console.log(`- ${employee.name}: ${identity} | last poll: ${employeeState?.last_poll_at || 'never'} | tracked open tasks: ${openTasks}`)
  }
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
      console.log('Edit it: add one entry per employee with its Matilda API key and role.')
      break
    }
    case 'status':
      await cmdStatus()
      break
    case 'start':
      await startLoop(loadConfig(), { once: args.includes('--once') })
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
