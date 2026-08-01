// Poll loop: for each employee, pick up assigned open tasks that need attention.
import { MatildaClient } from './matilda.js'
import { runTaskSession } from './agent.js'
import { loadState, saveState, appendLog, setActivity } from './config.js'


// A task needs attention when it's new to us, when someone else commented last
// (Matilda sets `unresolved: true` when the last comment is not the assignee's —
// note: comments do NOT touch the task's updated_at), or when the task itself changed.
// If unresolved was already true after our last session (we failed to reply),
// retry only after a cooldown to avoid hammering a task the agent can't handle.
const RETRY_COOLDOWN_MS = 30 * 60 * 1000

function needsAttention (task, taskState) {
  if (!taskState) return true
  if (task.unresolved) {
    if (!taskState.unresolved) return true
    return Date.now() - Date.parse(taskState.handled_at) > RETRY_COOLDOWN_MS
  }
  return taskState.updated_at !== task.updated_at
}

async function pollEmployee (employee, state, log) {
  const client = new MatildaClient(state.server, employee.api_key)
  const me = await client.me()
  const employeeState = state.data.employees[employee.name] ||= { tasks: {} }

  const { data: tasks } = await client.listTasks({ user_id: me.id, completed: false, per_page: 100 })
  employeeState.last_poll_at = new Date().toISOString()

  for (const task of tasks) {
    const taskState = employeeState.tasks[task.id]
    if (!needsAttention(task, taskState)) continue

    log(`${employee.name}: working on task #${task.id} "${task.title}"`)
    setActivity({ employee: employee.name, task_id: task.id, task_title: task.title, started_at: new Date().toISOString() })
    try {
      const outcome = await runTaskSession(employee, me, client, task, {
        onEvent: (kind, text) => log(`${employee.name} [${kind}] ${text}`)
      })
      log(`${employee.name}: task #${task.id} done (${outcome.turns} turns, $${outcome.cost_usd?.toFixed(4)})`)
    } catch (err) {
      log(`${employee.name}: session failed on task #${task.id}: ${err.message}`)
      appendLog(employee.name, { kind: 'error', task_id: task.id, error: err.message })
    } finally {
      setActivity(null)
    }

    // Refresh state after the session: our own comment resets unresolved server-side,
    // so storing the fresh values prevents reprocessing our own activity.
    let fresh = task
    try { fresh = await client.getTask(task.id) } catch {}
    employeeState.tasks[task.id] = {
      handled_at: new Date().toISOString(),
      updated_at: fresh.updated_at,
      unresolved: fresh.unresolved
    }
  }

  // Drop state for tasks no longer open (completed or reassigned).
  const openIds = new Set(tasks.map((task) => String(task.id)))
  for (const id of Object.keys(employeeState.tasks)) {
    if (!openIds.has(id)) delete employeeState.tasks[id]
  }

}

export async function startLoop (config, { once = false, log = console.log } = {}) {
  const interval = Math.min(...config.employees.map((e) => e.poll_interval || 300)) * 1000
  const state = { server: config.server, data: loadState() }
  let running = true
  let wake = null

  // Graceful stop: finish the session in flight, skip the rest of the sleep.
  const stop = () => { running = false; wake?.(); log('Stopping after current work...') }
  process.on('SIGINT', stop)
  process.on('SIGTERM', stop)

  while (running) {
    for (const employee of config.employees) {
      if (!running) break
      try {
        await pollEmployee(employee, state, log)
      } catch (err) {
        log(`${employee.name}: poll failed: ${err.message}`)
      }
      saveState(state.data)
    }
    if (once || !running) break
    log(`Round complete. Sleeping ${interval / 1000}s.`)
    await new Promise((resolve) => {
      wake = resolve
      // A stop signal may land between the running check and this point:
      // resolve immediately instead of sleeping a full interval.
      if (!running) return resolve()
      setTimeout(resolve, interval)
    })
    wake = null
  }
}
