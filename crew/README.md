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
      "role": "Junior PM: triage assigned tasks, answer questions in comments, publish weekly reports.",
      "poll_interval": 300,
      "max_turns": 15
    }
  ]
}
```

Optional per-employee: `model` (defaults to the Claude Code default).

## Run

```bash
crew status        # verify each employee reaches Matilda
crew start         # poll loop: picks up open tasks assigned to each employee
crew start --once  # single round, useful for cron
crew ask ada "che task ho in scadenza questa settimana?"
crew update        # self-update from the Matilda server package
```

How the loop decides to act on a task: it is assigned to the employee, not completed, changed since last handling, and the last comment is not the employee's own. To hand work to an employee, assign the task; to reply to it, comment on the task.

State and activity logs live in `~/.matilda-crew/` (`state.json`, `logs/<name>.jsonl`). Package updates never touch them.

## Publishing the package (Matilda server side)

```bash
rake crew:pack
```

Builds the npm tarball into `public/crew/` plus a `manifest.json` used by `crew update`. Requires `npm` on the machine running the task.
