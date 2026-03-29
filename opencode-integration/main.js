#!/usr/bin/env node

const fs = require("fs");
const path = require("path");
const https = require("https");
const http = require("http");
const { spawn } = require("child_process");

// --- Configuration ---

const CONFIG_PATH = path.join(__dirname, "config.json");
const INSTRUCTIONS_PATH = path.join(__dirname, "INSTRUCTIONS.md");
const LOOP_INTERVAL_MS = 30_000; // 30 seconds
const SERVICE_NAME = "OpenCode";

// --- State ---

// Tracks running opencode agents: taskId -> { process, output, sessionId }
const runningAgents = new Map();

// --- Helpers ---

function loadConfig() {
  const raw = fs.readFileSync(CONFIG_PATH, "utf-8");
  return JSON.parse(raw);
}

function loadInstructions() {
  try {
    return fs.readFileSync(INSTRUCTIONS_PATH, "utf-8");
  } catch {
    return "";
  }
}

function apiRequest(config, method, apiPath, body = null) {
  return new Promise((resolve, reject) => {
    const url = new URL(apiPath, config.matilda_api_url);
    const isHttps = url.protocol === "https:";
    const transport = isHttps ? https : http;

    const options = {
      hostname: url.hostname,
      port: url.port || (isHttps ? 443 : 80),
      path: url.pathname + url.search,
      method,
      headers: {
        "X-API-Key": config.matilda_api_key,
        "Content-Type": "application/json",
      },
    };

    const req = transport.request(options, (res) => {
      let data = "";
      res.on("data", (chunk) => (data += chunk));
      res.on("end", () => {
        try {
          resolve({ status: res.statusCode, data: data ? JSON.parse(data) : null });
        } catch {
          resolve({ status: res.statusCode, data });
        }
      });
    });

    req.on("error", reject);

    if (body) {
      req.write(JSON.stringify(body));
    }

    req.end();
  });
}

function log(message) {
  const timestamp = new Date().toISOString();
  console.log(`[${timestamp}] ${message}`);
}

function logError(message) {
  const timestamp = new Date().toISOString();
  console.error(`[${timestamp}] ERROR: ${message}`);
}

function getLastComment(task) {
  if (!task.tasks_comments || task.tasks_comments.length === 0) {
    return null;
  }
  // Sort by created_at descending and return the most recent
  const sorted = [...task.tasks_comments].sort(
    (a, b) => new Date(b.created_at) - new Date(a.created_at)
  );
  return sorted[0];
}

function isLastCommentFromOpenCode(task) {
  const last = getLastComment(task);
  return last && last.service === SERVICE_NAME;
}

function buildPrompt(task, instructions) {
  let prompt = "";

  if (instructions) {
    prompt += `## Custom Instructions\n\n${instructions}\n\n`;
  }

  prompt += `## Task\n\n`;
  prompt += `**Title:** ${task.title}\n\n`;

  if (task.content) {
    // Strip HTML tags for a cleaner prompt
    const cleanContent = task.content.replace(/<[^>]*>/g, "").trim();
    if (cleanContent) {
      prompt += `**Description:**\n${cleanContent}\n\n`;
    }
  }

  if (task.tasks_comments && task.tasks_comments.length > 0) {
    prompt += `## Conversation History\n\n`;
    const sorted = [...task.tasks_comments].sort(
      (a, b) => new Date(a.created_at) - new Date(b.created_at)
    );
    for (const comment of sorted) {
      const author = comment.service === SERVICE_NAME ? "OpenCode Agent" : "User";
      const date = new Date(comment.created_at).toLocaleString();
      prompt += `**${author}** (${date}):\n${comment.content}\n\n`;
    }
    prompt += `Please continue working on this task based on the user's latest feedback.\n`;
  }

  return prompt;
}

// --- Core Logic ---

async function ping(config) {
  try {
    const machine = require("os").hostname();
    await apiRequest(config, "POST", "/apis/opencode-integration/ping", { machine });
    log("Ping sent successfully");
  } catch (err) {
    logError(`Ping failed: ${err.message}`);
  }
}

async function fetchTasks(config) {
  try {
    const res = await apiRequest(
      config,
      "GET",
      "/apis/tasks?completed=false&opencode_assignment=true"
    );
    if (res.status === 200 && Array.isArray(res.data)) {
      return res.data;
    }
    logError(`Failed to fetch tasks: status ${res.status}`);
    return [];
  } catch (err) {
    logError(`Failed to fetch tasks: ${err.message}`);
    return [];
  }
}

async function fetchTaskDetails(config, taskId) {
  try {
    const res = await apiRequest(config, "GET", `/apis/tasks/${taskId}`);
    if (res.status === 200 && res.data) {
      return res.data;
    }
    logError(`Failed to fetch task ${taskId}: status ${res.status}`);
    return null;
  } catch (err) {
    logError(`Failed to fetch task ${taskId}: ${err.message}`);
    return null;
  }
}

async function postComment(config, taskId, content) {
  try {
    const res = await apiRequest(config, "POST", `/apis/tasks/${taskId}/comment`, {
      service: SERVICE_NAME,
      content,
    });
    if (res.status >= 200 && res.status < 300) {
      log(`Comment posted on task ${taskId}`);
      return true;
    }
    logError(`Failed to post comment on task ${taskId}: status ${res.status}`);
    return false;
  } catch (err) {
    logError(`Failed to post comment on task ${taskId}: ${err.message}`);
    return false;
  }
}

function startAgent(taskId, prompt) {
  log(`Starting OpenCode agent for task ${taskId}`);

  const permissions = JSON.stringify({ external_directory: "allow" });

  const child = spawn("opencode", ["run", prompt], {
    stdio: ["ignore", "pipe", "pipe"],
    env: { ...process.env, OPENCODE_PERMISSION: permissions },
  });

  let stdout = "";
  let stderr = "";

  child.stdout.on("data", (chunk) => {
    stdout += chunk.toString();
  });

  child.stderr.on("data", (chunk) => {
    stderr += chunk.toString();
  });

  child.on("error", (err) => {
    logError(`Agent process error for task ${taskId}: ${err.message}`);
    logError(`This may be a permissions issue. Stopping program.`);
    process.exit(1);
  });

  child.on("close", (code) => {
    const agent = runningAgents.get(taskId);
    if (agent) {
      agent.finished = true;
      agent.exitCode = code;
      agent.stdout = stdout;
      agent.stderr = stderr;

      if (code !== 0) {
        logError(`Agent for task ${taskId} exited with code ${code}`);
        logError(`stderr: ${stderr}`);
        logError(`Permission or execution error detected. Stopping program.`);
        process.exit(1);
      } else {
        log(`Agent for task ${taskId} completed successfully`);
      }
    }
  });

  runningAgents.set(taskId, {
    process: child,
    finished: false,
    exitCode: null,
    stdout: "",
    stderr: "",
  });
}

function extractAgentOutput(agent) {
  // opencode run writes its output to stderr (stdout is empty in non-TTY mode)
  const combined = (agent.stdout + agent.stderr);
  // Strip ANSI escape codes
  let raw = combined.replace(/\x1b\[[0-9;]*m/g, "").trim();
  if (!raw) return null;

  // Remove opencode internal noise lines
  raw = raw
    .split("\n")
    .filter((line) => {
      const trimmed = line.trim();
      if (trimmed.startsWith("> build ·")) return false;
      if (trimmed.startsWith("← ")) return false;
      if (trimmed === "Wrote file successfully.") return false;
      if (trimmed.startsWith("Shell cwd was reset")) return false;
      return true;
    })
    .join("\n")
    .replace(/\n{3,}/g, "\n\n")
    .trim();

  if (!raw) return null;

  if (raw.length > 5000) {
    return raw.slice(-5000);
  }
  return raw;
}

async function handleTask(config, task, instructions) {
  const taskId = task.id;
  const agent = runningAgents.get(taskId);

  // Case 1: Agent is currently running
  if (agent && !agent.finished) {
    log(`Task ${taskId}: agent is still running, skipping`);
    return;
  }

  // Case 2: Agent finished, need to post output
  if (agent && agent.finished) {
    const output = extractAgentOutput(agent);
    if (output) {
      log(`Task ${taskId}: agent finished, posting output as comment`);
      await postComment(config, taskId, output);
    } else {
      log(`Task ${taskId}: agent finished but no output to post`);
      await postComment(config, taskId, "Task completed. No additional output to report.");
    }
    runningAgents.delete(taskId);
    return;
  }

  // Case 3: No agent running - check comments
  if (isLastCommentFromOpenCode(task)) {
    // Last comment is from OpenCode, waiting for user feedback
    log(`Task ${taskId}: waiting for user feedback, skipping`);
    return;
  }

  // Case 4: No agent running and last comment is NOT from OpenCode (or no comments)
  // Start a new agent
  const prompt = buildPrompt(task, instructions);
  startAgent(taskId, prompt);
}

// --- Main Loop ---

async function mainLoop() {
  const config = loadConfig();
  const instructions = loadInstructions();

  log("OpenCode Integration started");
  log(`API URL: ${config.matilda_api_url}`);

  while (true) {
    try {
      // Send ping
      await ping(config);

      // Fetch task list
      const taskList = await fetchTasks(config);
      log(`Found ${taskList.length} task(s) to process`);

      // Process each task
      for (const taskSummary of taskList) {
        const task = await fetchTaskDetails(config, taskSummary.id);
        if (task) {
          await handleTask(config, task, instructions);
        }
      }
    } catch (err) {
      logError(`Main loop error: ${err.message}`);
    }

    // Wait before next iteration
    await new Promise((resolve) => setTimeout(resolve, LOOP_INTERVAL_MS));
  }
}

mainLoop().catch((err) => {
  logError(`Fatal error: ${err.message}`);
  process.exit(1);
});
