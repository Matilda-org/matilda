// Agent sessions: one query() per unit of work, Matilda tools only.
import { query } from '@anthropic-ai/claude-agent-sdk'
import { buildMatildaServer, SERVER_NAME, ALLOWED_TOOLS } from './tools.js'
import { appendLog } from './config.js'

function systemPrompt (employee, me) {
  return [
    `You are "${employee.name}", a virtual employee working on the Matilda project management system.`,
    `Your Matilda user id is ${me.id}. Your role: ${employee.role}`,
    '',
    'Rules:',
    '- Work only through the Matilda tools. You have no filesystem or shell.',
    '- Always report your work as a task comment (comment_task) so humans can read it.',
    '- Complete a task (complete_task) only when the requested work is truly done.',
    '- If you cannot do something or need input, say so in a comment and do NOT complete the task.',
    '- Write comments in the same language the task is written in.',
    '- Be concise and concrete: results first, then reasoning if useful.'
  ].join('\n')
}

// Run one session and return { result, cost, turns }.
async function runSession (employee, me, client, prompt, { onEvent } = {}) {
  const server = buildMatildaServer(client)
  let result = null
  let usage = null

  for await (const message of query({
    prompt,
    options: {
      systemPrompt: systemPrompt(employee, me),
      mcpServers: { [SERVER_NAME]: server },
      allowedTools: ALLOWED_TOOLS,
      permissionMode: 'dontAsk',
      maxTurns: employee.max_turns || 15,
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
