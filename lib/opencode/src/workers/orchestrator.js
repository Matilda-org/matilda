import { parentPort } from "node:worker_threads"
import { createRequire } from "node:module"
import fs from "node:fs"
import path from "node:path"
import { logPhase } from "../logger.js"
import { fetchTasks, fetchTaskDetails, postComment } from "../apis.js"
import { readMemory, writeMemory, cleanMemory } from "../memory.js"
import cleanHTML from "../func/cleanHTML.js"
import { prompt as opencodePrompt } from "../opencode.js"

const require = createRequire(import.meta.url)
const config = require("../../config.json")

const LOOP_MS = 30_000

async function buildTaskPrompt(taskDetails) {
  const description = cleanHTML(taskDetails.content)

  let prompt = `Title: ${taskDetails.title}`
  if (description) prompt += `\n\nDescription:\n${description}`
  if (taskDetails.tasks_comments && taskDetails.tasks_comments.length > 0) {
    prompt += `\n\nComments:\n`
    taskDetails.tasks_comments.forEach((taskComment, index) => {
      const comment = { author: null, content: taskComment.content }
      if (taskComment.service == 'OpenCode') {
        comment.author = 'AI'
      } else {
        comment.author = taskComment.service ? `SERVICE(${taskComment.service})` : 'USER'
      }

      prompt += `- ${comment.author}: ${cleanHTML(comment.content)}\n`
    })
  }

  return prompt
}

async function findTaskWorkdir(task, taskPrompt) {
  const workdirKey = "workdir"
  let workdir = await readMemory(task.id, workdirKey)
  if (workdir) return workdir

  const result = await opencodePrompt({
    title: `MO: ${task.title} - Find workdir`,
    directory: config.workdir,
    prompt: `
We want to find a the workdir for the task.
These are the task details:
${taskPrompt}

Based on the task details, suggest a suitable workdir path for this task, that should be inside ${config.workdir}.
Only respond with the path, without any explanation. If you think that the task is too generic and can be done in the root folder, just respond with ".".
`.trim()
  })

  if (!result.text) {
    await postComment(task.id, "I cannot determine a suitable workdir for this task. Please provide more details or specify a workdir.")
    return null
  }

  const suggestedPath = result.text.trim()
  const fullPath = path.resolve(config.workdir, suggestedPath)
  if (!fullPath.startsWith(path.resolve(config.workdir))) {
    await postComment(task.id, `I suggest to work on "${suggestedPath}" but it is outside of the allowed root directory.`)
    return null
  }

  await writeMemory(task.id, workdirKey, suggestedPath)
  return suggestedPath
}

async function executeTask(task, taskPrompt, taskWorkdir) {
  const result = await opencodePrompt({
    title: `MO: ${task.title} - Execute task`,
    directory: path.resolve(config.workdir, taskWorkdir),
    prompt: `
We want to execute the task with the following details:
${taskPrompt}

Please perform the necessary actions to complete the task.
`.trim()
  })

  if (!result.text) {
    await postComment(task.id, "I attempted to execute the task but I couldn't determine if it was completed or if I needed more information. I did not generate any response.")
    return null
  }

  const response = result.text.trim().toUpperCase()
  await postComment(task.id, response)

  return response
}

async function manageTask(task) {
  logPhase("orchestrator", `Managing task ${task.id} - ${task.title}`)
  if (task.unresolved) {
    logPhase("orchestrator", `Task ${task.id} is unresolved, skipping...`)
    return
  }

  const details = await fetchTaskDetails(task.id)
  if (!details) {
    logPhase("orchestrator", `Failed to fetch details for task ${task.id}, skipping...`)
    return
  }

  const taskPrompt = await buildTaskPrompt(details)
  const taskWorkdir = await findTaskWorkdir(task, taskPrompt)
  if (!taskWorkdir) {
    logPhase("orchestrator", `No valid workdir for task ${task.id}, skipping...`)
    return
  }

  const execution = await executeTask(task, taskPrompt, taskWorkdir)
  if (!execution) {
    logPhase("orchestrator", `Execution failed for task ${task.id}`)
    return
  }

  logPhase("orchestrator", `Execution completed for task ${task.id}`)
}

async function loop() {
  await cleanMemory() // Clean old memory files on each loop
  logPhase("orchestrator", "Loop started")

  const tasks = await fetchTasks()
  logPhase("orchestrator", `Fetched ${tasks.length} tasks`)

  if (tasks.length <= 0) {
    logPhase("orchestrator", "No tasks found, sleeping...")
    setTimeout(async () => await loop(), LOOP_MS)
    return
  }

  for (const task of tasks) {
    await manageTask(task)
  }

  setTimeout(async () => await loop(), LOOP_MS)
}

async function run() {
  logPhase("orchestrator", "Worker started")
  await loop()
}

run()

