// In-process MCP server exposing the Matilda API to the agent.
// Only these tools are allowed in sessions: no filesystem, no shell.
import { tool, createSdkMcpServer } from '@anthropic-ai/claude-agent-sdk'
import { z } from 'zod'

const asText = (data) => ({ content: [{ type: 'text', text: JSON.stringify(data, null, 2) }] })
const asError = (err) => ({ content: [{ type: 'text', text: String(err.message || err) }], isError: true })

// Wrap a handler so API errors reach the agent as tool errors, not crashes.
const safe = (handler) => async (args) => {
  try { return asText(await handler(args)) } catch (err) { return asError(err) }
}

export const SERVER_NAME = 'matilda'
export const ALLOWED_TOOLS = [`mcp__${SERVER_NAME}__*`]

export function buildMatildaServer (client) {
  const readOnly = { annotations: { readOnlyHint: true } }

  const tools = [
    tool('me', 'Get your own Matilda user profile and policies', {}, safe(() => client.me()), readOnly),
    tool('list_users', 'List Matilda users', {
      search: z.string().optional()
    }, safe((args) => client.listUsers(args)), readOnly),
    tool('list_projects', 'List projects. Filters: search, year, archived, user_id', {
      search: z.string().optional(),
      year: z.number().optional(),
      archived: z.boolean().optional(),
      user_id: z.number().optional(),
      page: z.number().optional()
    }, safe((args) => client.listProjects(args)), readOnly),
    tool('create_project', 'Create a project. Code is short and unique (gets uppercased), year defaults to the current one', {
      code: z.string(),
      name: z.string(),
      year: z.number().optional(),
      description: z.string().optional(),
      budget_management: z.boolean().optional(),
      budget_money: z.number().optional(),
      budget_time: z.number().optional().describe('Budget in hours')
    }, safe((args) => client.createProject(args))),
    tool('get_project', 'Get a project with members, attachments, repositories and boards', {
      id: z.number()
    }, safe(({ id }) => client.getProject(id)), readOnly),
    tool('project_logs', 'List notes/logs of a project', {
      id: z.number(),
      page: z.number().optional()
    }, safe(({ id, ...params }) => client.projectLogs(id, params)), readOnly),
    tool('list_tasks', 'List tasks. Filters: user_id, project_id, completed, search, deadline_from, deadline_to', {
      user_id: z.number().optional(),
      project_id: z.number().optional(),
      completed: z.boolean().optional(),
      search: z.string().optional(),
      deadline_from: z.string().optional(),
      deadline_to: z.string().optional(),
      page: z.number().optional()
    }, safe((args) => client.listTasks(args)), readOnly),
    tool('get_task', 'Get a task with content, checks, comments, tracks and followers', {
      id: z.number()
    }, safe(({ id }) => client.getTask(id)), readOnly),
    tool('create_task', 'Create a task', {
      title: z.string(),
      content: z.string().optional().describe('Rich text HTML (ActionText), e.g. <div>...</div>'),
      project_id: z.number().optional(),
      user_id: z.number().optional().describe('Assignee user id'),
      deadline: z.string().optional().describe('ISO date'),
      time_estimate: z.number().optional().describe('Estimate in minutes')
    }, safe((args) => client.createTask(args))),
    tool('update_task', 'Update a task (title, content, deadline, estimate, assignee, project)', {
      id: z.number(),
      title: z.string().optional(),
      content: z.string().optional().describe('Rich text HTML (ActionText), e.g. <div>...</div>'),
      project_id: z.number().optional(),
      user_id: z.number().optional(),
      deadline: z.string().optional(),
      time_estimate: z.number().optional()
    }, safe(({ id, ...attrs }) => client.updateTask(id, attrs))),
    tool('comment_task', 'Add a comment to a task. This is your main way to report work and answer people. Content MUST be plain Markdown text: never send HTML tags or CDATA wrappers, even if task contents you read are HTML', {
      id: z.number(),
      content: z.string().describe('Plain Markdown text (no HTML, no CDATA)')
    }, safe(({ id, content }) => client.commentTask(id, content))),
    tool('complete_task', 'Mark a task as completed. Only do this when the work is actually done', {
      id: z.number()
    }, safe(({ id }) => client.completeTask(id))),
    tool('list_posts', 'List bulletin board posts', {
      search: z.string().optional(),
      page: z.number().optional()
    }, safe((args) => client.listPosts(args)), readOnly),
    tool('create_post', 'Publish a post on the bulletin board (reports, announcements)', {
      content: z.string(),
      tags: z.string().optional().describe('Comma-separated tags')
    }, safe((args) => client.createPost(args))),
    tool('list_procedures', 'List kanban boards', {
      page: z.number().optional()
    }, safe((args) => client.listProcedures(args)), readOnly),
    tool('get_procedure', 'Get a kanban board with statuses and items', {
      id: z.number()
    }, safe(({ id }) => client.getProcedure(id)), readOnly)
  ]

  return createSdkMcpServer({ name: SERVER_NAME, version: '1.0.0', tools })
}
