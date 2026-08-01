// Thin client for the Matilda API v1. One instance per employee (own API key).
export class MatildaClient {
  constructor (server, apiKey) {
    this.base = server.replace(/\/$/, '')
    this.apiKey = apiKey
  }

  async request (method, path, { params, body } = {}) {
    const url = new URL(`${this.base}/api/v1${path}`)
    if (params) {
      for (const [key, value] of Object.entries(params)) {
        if (value !== undefined && value !== null) url.searchParams.set(key, value)
      }
    }
    const res = await fetch(url, {
      method,
      headers: {
        'X-API-Key': this.apiKey,
        'Content-Type': 'application/json'
      },
      body: body ? JSON.stringify(body) : undefined
    })
    const text = await res.text()
    let json
    try { json = text ? JSON.parse(text) : null } catch { json = { raw: text } }
    if (!res.ok) {
      const message = json?.error || json?.message || res.statusText
      throw new Error(`Matilda API ${res.status} on ${method} ${path}: ${message}`)
    }
    return json
  }

  me () { return this.request('GET', '/me') }
  listUsers (params) { return this.request('GET', '/users', { params }) }
  listProjects (params) { return this.request('GET', '/projects', { params }) }
  getProject (id) { return this.request('GET', `/projects/${id}`) }
  projectLogs (id, params) { return this.request('GET', `/projects/${id}/logs`, { params }) }
  listTasks (params) { return this.request('GET', '/tasks', { params }) }
  getTask (id) { return this.request('GET', `/tasks/${id}`) }
  createTask (attrs) { return this.request('POST', '/tasks', { body: attrs }) }
  updateTask (id, attrs) { return this.request('PATCH', `/tasks/${id}`, { body: attrs }) }
  completeTask (id) { return this.request('POST', `/tasks/${id}/complete`) }
  uncompleteTask (id) { return this.request('POST', `/tasks/${id}/uncomplete`) }
  commentTask (id, content) {
    return this.request('POST', `/tasks/${id}/comments`, { body: { content, service: 'crew' } })
  }
  listPosts (params) { return this.request('GET', '/posts', { params }) }
  createPost (attrs) { return this.request('POST', '/posts', { body: attrs }) }
  listProcedures (params) { return this.request('GET', '/procedures', { params }) }
  getProcedure (id) { return this.request('GET', `/procedures/${id}`) }
}
