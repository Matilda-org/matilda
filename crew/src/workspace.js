// Deterministic worktree lifecycle, owned by the loop — never by the agent.
// Per session: mount a worktree on branch crew/<task_id>, run, then save any
// leftovers and unmount. Only the branch survives between sessions.
import fs from 'node:fs'
import path from 'node:path'
import { execFileSync } from 'node:child_process'
import { HOME_DIR } from './config.js'

export const WORKTREES_DIR = path.join(HOME_DIR, 'worktrees')

const git = (repo, ...args) =>
  execFileSync('git', ['-C', repo, ...args], { encoding: 'utf8', stdio: ['ignore', 'pipe', 'pipe'] }).trim()

// Local folder of the repository linked to the task's Matilda project:
// match repo names (last segment of "org/name") against workspace folders.
export async function findRepoDir (client, task, workspace) {
  if (!task.project_id) return null
  let project
  try { project = await client.getProject(task.project_id) } catch { return null }
  const names = (project.projects_repositories || [])
    .map((repo) => String(repo.name || '').split('/').pop().toLowerCase())
    .filter(Boolean)
  if (!names.length) return null

  for (const dir of workspace) {
    let entries = []
    try { entries = fs.readdirSync(dir) } catch { continue }
    for (const entry of entries) {
      if (!names.includes(entry.toLowerCase())) continue
      const candidate = path.join(dir, entry)
      if (fs.existsSync(path.join(candidate, '.git'))) return candidate
    }
  }
  return null
}

// Mount the task worktree. Survives forced kills: stale registrations are
// pruned and an already-mounted worktree is reused as is.
export function setupWorktree (repoDir, taskId) {
  const branch = branchFor(repoDir, taskId)
  const worktreePath = path.join(WORKTREES_DIR, `${path.basename(repoDir)}-${taskId}`)
  fs.mkdirSync(WORKTREES_DIR, { recursive: true })
  git(repoDir, 'worktree', 'prune')

  if (!fs.existsSync(path.join(worktreePath, '.git'))) {
    if (git(repoDir, 'branch', '--list', branch) !== '') {
      git(repoDir, 'worktree', 'add', worktreePath, branch)
    } else {
      git(repoDir, 'worktree', 'add', worktreePath, '-b', branch, defaultRef(repoDir))
    }
  }
  return { repoDir, path: worktreePath, branch }
}

// Reuse the task's existing crew branch when present (older naming carried a
// slug: crew/<id>-<slug>), otherwise settle on the canonical crew/<id>.
function branchFor (repoDir, taskId) {
  const existing = git(repoDir, 'branch', '--list', `crew/${taskId}`, `crew/${taskId}-*`)
    .split('\n')
    .map((line) => line.replace(/^[*+]\s*/, '').trim())
    .filter(Boolean)
  return existing[0] || `crew/${taskId}`
}

function defaultRef (repoDir) {
  try { return git(repoDir, 'symbolic-ref', '--short', 'refs/remotes/origin/HEAD') } catch {}
  for (const name of ['main', 'master']) {
    if (git(repoDir, 'branch', '--list', name) !== '') return name
  }
  return 'HEAD'
}

// Save uncommitted leftovers (timeout / kill mid-work), then unmount.
export function teardownWorktree (worktree) {
  if (git(worktree.path, 'status', '--porcelain') !== '') {
    git(worktree.path, 'add', '-A')
    git(worktree.path, 'commit', '-m', 'wip(crew): autosave at session end')
  }
  git(worktree.repoDir, 'worktree', 'remove', worktree.path)
}
