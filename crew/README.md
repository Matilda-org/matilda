# Matilda Crew

Run Claude-powered pseudo-employees against your Matilda instance. Each employee is a real Matilda user (own API key, own policies) driven locally by a Claude agent: it picks up tasks assigned to it, works through the Matilda API, reports results as task comments and completes tasks when done.

## Requirements

- Node.js >= 20
- Claude authentication, one of:
  - `ANTHROPIC_API_KEY` env var (metered API billing — recommended if you share this tool with others)
  - being logged into Claude Code on this machine with a Claude subscription (used automatically as fallback when no API key is set; `claude setup-token` generates a long-lived `CLAUDE_CODE_OAUTH_TOKEN` for headless/cron setups). Note: agent sessions share your subscription rate limits with your interactive Claude Code usage.

## Install

From your Matilda instance (see Strumenti → Matilda Crew for the exact URL):

```bash
npm install -g https://<your-matilda-host>/crew/matilda-crew-latest.tgz
```

## Setup

1. In Matilda, create one user per employee. Give it only the policies it needs (e.g. `tasks_index`, `tasks_show`, `tasks_comment`, `tasks_complete`, `posts_create`) and add it as member of the relevant projects.
2. Regenerate its API key from the user page and copy it.
3. Initialize and edit the config:

```bash
crew init --server https://your-matilda-host
```

Config lives in `~/.matilda-crew/config.json`:

```json
{
  "server": "https://your-matilda-host",
  "employees": [
    {
      "name": "ada",
      "api_key": "...",
      "description": "Junior PM: triage assigned tasks, answer questions in comments, publish weekly reports.",
      "poll_interval": 300,
      "session_timeout": 30
    }
  ]
}
```

The LLM instructions are the **profile description saved in Matilda** (user page, shared and human-visible) concatenated with the local `description` above (machine-specific). Both are optional.

Optional per-employee:

- `model` — Claude model used for the employee's sessions, e.g. `"claude-sonnet-5"`, `"claude-opus-5"` or an alias like `"sonnet"`/`"opus"`. Unset = the default model of your local Claude Code installation (subscription login or API key, see Requirements). Cheaper models keep the loop economical; stronger models reason better on vague tasks.
- `session_timeout` — wall-clock limit per session in minutes (default 30). Sessions have **no turn cap**: they run until the work is done or the timeout fires. The incremental-commit rule means a timed-out coding session still leaves its finished pieces committed.
- `max_turns` — optional hard cap of agent turns per session; unset = unlimited
All sessions can read the web (`WebFetch`/`WebSearch`) for research; the prompt instructs the agent to treat web content as data (prompt-injection guard) and never send private Matilda data outside.

- `workspace` — array of local directories holding your repositories (e.g. `["/Users/me/Workspace"]`). Grants Read/Grep/Glob/Edit/Write plus Bash restricted to `git` and the common test runners (`bin/rails test`, `npm/yarn test`) so the employee verifies its own changes. The worktree lifecycle is managed by the loop, not by the agent: before each session the task's repository (matched via the repositories linked to the Matilda project) gets a worktree mounted under `~/.matilda-crew/worktrees/` on branch `crew/<task_id>`; after the session uncommitted leftovers are auto-saved as a `wip` commit and the worktree is unmounted — between sessions only the branch exists, your checkout is never touched. Forced kills are handled (stale worktrees are pruned/reused). Tasks whose project has no linked repository are read-only. **Push is always forbidden**; every code change is reported in the task comment with repo, branch and diff-stat. Omit the field for a Matilda-only employee (no filesystem at all).

## Run

```bash
crew status          # loop state, per-employee tasks and recent activity
crew logs ada -n 20  # full activity log of one employee
crew start           # poll loop in foreground (Ctrl+C to stop)
crew start --daemon  # poll loop in background, logs to ~/.matilda-crew/crew.log
crew start --once    # single round, useful for cron
crew stop            # stop the loop — graceful: finishes the session in flight
crew restart         # stop + start --daemon (e.g. after editing the config)
crew ask ada "che task ho in scadenza questa settimana?"
crew update          # self-update from the Matilda server package
```

The loop writes a pidfile in `~/.matilda-crew/crew.pid`; `stop` waits up to 3 minutes for the agent session in flight before suggesting a force kill. Config changes require a `crew restart` to take effect.

How the loop decides to act on a task: it is assigned to the employee, not completed, changed since last handling, and the last comment is not the employee's own. To hand work to an employee, assign the task; to reply to it, comment on the task.

State and activity logs live in `~/.matilda-crew/` (`state.json`, `logs/<name>.jsonl`). Package updates never touch them.

## Start at login (macOS)

```bash
crew autostart --install   # launchd agent: the loop starts at login
crew autostart --uninstall
```

Pair it with SwiftBar set as a login item (System Settings → Login Items, or SwiftBar preferences) so the menu bar indicator is there too. `crew stop` keeps working: the agent has no KeepAlive, so a stopped loop stays stopped until you start it again (menu bar ▶️ or next login).

## macOS menu bar indicator

With [SwiftBar](https://github.com/swiftbar/SwiftBar) (or xbar) installed:

```bash
crew menubar --install
```

Shows ⚫️ loop stopped / 🟢 idle / 🔵 `#<task>` working, with a dropdown carrying the session in flight, recent activity per employee and clickable start/stop/restart. `crew menubar` prints the plugin output for debugging. Refresh interval is the number in the plugin filename (`crew.5s.sh`).

## Publishing the package (Matilda server side)

```bash
rake crew:pack
```

Builds the npm tarball into `public/crew/` plus a `manifest.json` used by `crew update`. Requires `npm` on the machine running the task.
