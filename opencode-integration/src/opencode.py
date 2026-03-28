import json
import subprocess
import logging

logger = logging.getLogger("matilda-opencode")


def run_opencode(prompt: str, cwd: str | None = None) -> str:
    cmd = ["opencode", "run", "--format", "json", prompt]
    logger.debug("Running opencode: %s", " ".join(cmd[:3]) + " <prompt>")
    try:
        result = subprocess.run(
            cmd,
            capture_output=True,
            text=True,
            timeout=600,
            cwd=cwd,
        )
        output = _extract_text_from_json(result.stdout)
        if not output and result.returncode != 0 and result.stderr:
            output = f"ERRORE:\n{result.stderr.strip()}"
        return output
    except subprocess.TimeoutExpired:
        return "ERRORE: timeout di esecuzione OpenCode (10 minuti)"


def _extract_text_from_json(raw: str) -> str:
    """Extract text parts from opencode JSON stream output."""
    texts = []
    for line in raw.strip().splitlines():
        line = line.strip()
        if not line:
            continue
        try:
            event = json.loads(line)
            if event.get("type") == "text":
                text = event.get("part", {}).get("text", "")
                if text:
                    texts.append(text)
        except json.JSONDecodeError:
            continue
    return "".join(texts)


def build_evaluation_prompt(instructions: str, task: dict) -> str:
    project_name = task.get("project", {}).get("name", "N/A") if isinstance(task.get("project"), dict) else "N/A"
    checks = _format_checks(task.get("tasks_checks", []))
    comments = _format_comments(task.get("tasks_comments", []))

    return f"""{instructions}

## Task da valutare

Titolo: {task.get("title", "")}
Output atteso: {task.get("output", "")}
Deadline: {task.get("deadline", "")}
Progetto: {project_name}

## Checklist
{checks}

## Commenti esistenti
{comments}

---

Analizza il task. Stabilisci se hai abbastanza informazioni per portarlo a termine autonomamente.

Rispondi ESCLUSIVAMENTE in uno di questi formati:

READY
(nessun testo aggiuntivo — hai tutto il necessario)

SKIP - <motivo>
(il task non va eseguito, motivo specificato dopo il trattino)

DOMANDE
- Domanda 1
- Domanda 2
(elenca le informazioni mancanti necessarie per procedere)"""


def build_execution_prompt(instructions: str, task: dict) -> str:
    project_name = task.get("project", {}).get("name", "N/A") if isinstance(task.get("project"), dict) else "N/A"
    checks = _format_checks(task.get("tasks_checks", []))
    comments = _format_comments(task.get("tasks_comments", []))

    return f"""{instructions}

## Task da eseguire

Titolo: {task.get("title", "")}
Output atteso: {task.get("output", "")}
Deadline: {task.get("deadline", "")}
Progetto: {project_name}

## Checklist
{checks}

## Informazioni raccolte
{comments}

---

Porta a termine il task. Al termine produci un report strutturato con:
- Riepilogo di cosa è stato fatto
- File creati o modificati (se applicabile)
- Eventuali problemi riscontrati o decisioni prese"""


def parse_evaluation_response(response: str) -> tuple[str, str]:
    """Returns (action, detail) where action is READY/SKIP/DOMANDE."""
    stripped = response.strip()
    if stripped.upper().startswith("READY"):
        return "READY", ""
    if stripped.upper().startswith("SKIP"):
        reason = stripped.split("-", 1)[1].strip() if "-" in stripped else "Nessun motivo specificato"
        return "SKIP", reason
    if stripped.upper().startswith("DOMANDE"):
        lines = stripped.split("\n", 1)
        questions = lines[1].strip() if len(lines) > 1 else stripped
        return "DOMANDE", questions
    # Fallback: treat as questions if can't parse
    return "DOMANDE", stripped


def _format_checks(checks: list) -> str:
    if not checks:
        return "Nessuna checklist"
    return "\n".join(f"- {'[x]' if c.get('completed') else '[ ]'} {c.get('title', c.get('content', ''))}" for c in checks)


def _format_comments(comments: list) -> str:
    if not comments:
        return "Nessun commento"
    lines = []
    for c in comments:
        author = c.get("service") or f"user:{c.get('user_id', '?')}"
        lines.append(f"[{author} @ {c.get('created_at', '?')}] {c.get('content', '')}")
    return "\n".join(lines)
