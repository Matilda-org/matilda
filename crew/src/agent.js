// Agent sessions: one query() per unit of work, Matilda tools only.
import { query } from '@anthropic-ai/claude-agent-sdk'
import { buildMatildaServer, SERVER_NAME, ALLOWED_TOOLS } from './tools.js'
import { appendLog } from './config.js'

function systemPrompt (employee, me) {
  // Instructions = profile description stored in Matilda (shared, human-visible)
  // + local config description (machine-specific). Either may be empty.
  const description = [me.description, employee.description].filter(Boolean).join('\n\n')
  const workspace = employee.workspace || []
  return [
    `You are "${employee.name}", a virtual employee working on the Matilda project management system.`,
    `Your Matilda user id is ${me.id}.`,
    ...(description ? [`Your role and instructions:\n${description}`] : []),
    '',
    'Rules:',
    ...(workspace.length
      ? [
          `- You can read and edit code in these local workspace directories: ${workspace.join(', ')}.`,
          '  Project repositories listed in Matilda (get_project) usually match folder names in the workspace.',
          '- NEVER switch branches or edit files in the user\'s checkout: it is shared and may hold their work in progress.',
          '  For code changes create a linked worktree next to the repo and work ONLY inside it:',
          '  `git -C <repo> worktree add <repo>-crew-<task-id> -b crew/<task-id>-<short-slug>`',
          '  (if the worktree or branch already exists from a previous session, reuse it and continue).',
          '- Commit incrementally with conventional messages as each piece is done — never leave finished work uncommitted.',
          '  If you are running low on turns, commit what you have and report partial progress instead of pushing on.',
          '- NEVER push, never force, never delete branches, stashes or worktrees.',
          '- When you change code, end your task comment with: repository, branch name, and the `git diff --stat` summary.'
        ]
      : ['- Work only through the Matilda tools. You have no filesystem or shell.']),
    '- Always report your work as a task comment (comment_task) so humans can read it.',
    '- Complete a task (complete_task) only when the requested work is truly done.',
    '- If you cannot do something or need input, say so in a comment and do NOT complete the task.',
    '- Write comments in the same language the task is written in.',
    '- Comments are plain Markdown. Task contents are HTML. Never wrap anything in CDATA.',
    '- Be concise and concrete: results first, then reasoning if useful.'
  ].join('\n')
}

// Coding tools granted only when a workspace is configured. Bash is restricted
// to git; reading goes through Read/Grep/Glob, editing through Edit/Write.
const WORKSPACE_TOOLS = ['Read', 'Grep', 'Glob', 'Edit', 'Write', 'MultiEdit', 'Bash(git:*)']

// Run one session and return { result, cost, turns }.
async function runSession (employee, me, client, prompt, { onEvent } = {}) {
  const server = buildMatildaServer(client)
  const workspace = employee.workspace || []
  let result = null
  let usage = null

  for await (const message of query({
    prompt,
    options: {
      systemPrompt: systemPrompt(employee, me),
      mcpServers: { [SERVER_NAME]: server },
      allowedTools: workspace.length ? [...ALLOWED_TOOLS, ...WORKSPACE_TOOLS] : ALLOWED_TOOLS,
      permissionMode: 'dontAsk',
      maxTurns: employee.max_turns || 15,
      ...(workspace.length ? { cwd: workspace[0], additionalDirectories: workspace.slice(1) } : {}),
      ...(employee.model ? { model: employee.model } : {})
    }
  })) {
    if (message.type === 'assistant' && onEvent) {
      for (const block of message.message.content || []) {
        if (block.type === 'text' && block.text.trim()) onEvent('text', block.text)
        if (block.type === 'tool_use') onEvent('tool', `${block.name} ${JSON.stringify(block.input)}`)
      }
    }
    if (message.type === 'result') {
      result = message.subtype === 'success' ? message.result : `[${message.subtype}]`
      usage = { cost_usd: message.total_cost_usd, turns: message.num_turns }
    }
  }

  return { result, ...usage }
}

// Handle one assigned task end-to-end.
export async function runTaskSession (employee, me, client, task, opts) {
  const detail = await client.getTask(task.id)
  const prompt = [
    `You have been assigned Matilda task #${task.id}. Here is its current state (JSON):`,
    '```json',
    JSON.stringify(detail, null, 2),
    '```',
    '',
    'Read it carefully (fetch project context with your tools if useful), do the work your role and tools allow,',
    'then report the outcome with comment_task. If — and only if — the request is fully satisfied, call complete_task.'
  ].join('\n')

  const outcome = await runSession(employee, me, client, prompt, opts)
  appendLog(employee.name, { kind: 'task', task_id: task.id, ...outcome })
  return outcome
}

// One-shot question from the CLI (`crew ask`).
export async function runAskSession (employee, me, client, question, opts) {
  const prompt = `A human operator asks you directly (answer here, do not comment on tasks unless asked):\n\n${question}`
  const outcome = await runSession(employee, me, client, prompt, opts)
  appendLog(employee.name, { kind: 'ask', question, ...outcome })
  return outcome
}
