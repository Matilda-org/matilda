// Agent sessions: one query() per unit of work, Matilda tools only.
import { query } from '@anthropic-ai/claude-agent-sdk'
import { buildMatildaServer, SERVER_NAME, ALLOWED_TOOLS } from './tools.js'
import { appendLog } from './config.js'
import { WORKTREES_DIR } from './workspace.js'

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
          `- You can READ code in these local workspace directories: ${workspace.join(', ')}.`,
          '- Code changes are allowed ONLY inside the prepared worktree announced in the task prompt: it is already',
          '  mounted on the task\'s dedicated branch. It is unmounted automatically after every session — uncommitted',
          '  leftovers get auto-saved, but only proper commits on the branch are real work: commit incrementally',
          '  with conventional messages as each piece is done.',
          '- If no worktree is announced, the task\'s project has no linked repository here: you cannot change code.',
          '  Say so in your comment if code work was expected (the fix: link the repository to the Matilda project).',
          '- NEVER run git checkout/switch/worktree, never push, never force, never delete branches or stashes,',
          '  never edit files in the user\'s checkouts outside your worktree.',
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
// No turn cap by default: sessions run until done. The real guard is a
// wall-clock timeout (session_timeout minutes, default 30) so a runaway
// session can't block the loop forever.
async function runSession (employee, me, client, prompt, { onEvent, worktree } = {}) {
  const server = buildMatildaServer(client)
  const workspace = employee.workspace || []
  const abort = new AbortController()
  const timeoutMs = (employee.session_timeout || 30) * 60 * 1000
  const timer = setTimeout(() => abort.abort(new Error(`session timeout after ${timeoutMs / 60000} minutes`)), timeoutMs)
  let result = null
  let usage = null

  try {
    for await (const message of query({
      prompt,
      options: {
        systemPrompt: systemPrompt(employee, me),
        mcpServers: { [SERVER_NAME]: server },
        allowedTools: workspace.length ? [...ALLOWED_TOOLS, ...WORKSPACE_TOOLS] : ALLOWED_TOOLS,
        permissionMode: 'dontAsk',
        abortController: abort,
        ...(employee.max_turns ? { maxTurns: employee.max_turns } : {}),
        ...(workspace.length
          ? { cwd: worktree?.path || workspace[0], additionalDirectories: [...workspace, WORKTREES_DIR] }
          : {}),
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
  } catch (err) {
    if (!abort.signal.aborted) throw err
    result = '[timeout]'
  } finally {
    clearTimeout(timer)
  }

  return { result, ...usage }
}

// Handle one assigned task end-to-end.
export async function runTaskSession (employee, me, client, task, opts = {}) {
  const detail = await client.getTask(task.id)
  const prompt = [
    `You have been assigned Matilda task #${task.id}. Here is its current state (JSON):`,
    '```json',
    JSON.stringify(detail, null, 2),
    '```',
    '',
    ...(opts.worktree
      ? [
          `A git worktree for this task is mounted at ${opts.worktree.path} (your current directory),`,
          `on branch ${opts.worktree.branch} of repository ${opts.worktree.repoDir}. All code changes go there.`,
          ''
        ]
      : []),
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
