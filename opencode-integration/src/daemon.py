import logging
import platform
import time
import signal
import sys

from .config import load_config, config_is_complete, run_setup_wizard, get_instructions, DEFAULT_POLL_INTERVAL
from .database import (
    get_connection,
    get_task,
    upsert_task,
    update_task_status,
    record_comment,
    get_last_comment_sent,
)
from .matilda_api import MatildaClient
from .opencode import (
    run_opencode,
    build_evaluation_prompt,
    build_execution_prompt,
    parse_evaluation_response,
)

logger = logging.getLogger("matilda-opencode")


def extract_task_data(detail: dict) -> dict:
    """Estrae solo i dati utili dal dettaglio completo di un task."""
    comments = []
    for c in detail.get("tasks_comments", []):
        author = "ai" if c.get("service") == "matilda-opencode" else "utente"
        comments.append({"author": author, "content": c.get("content", "")})

    return {
        "title": detail.get("title", ""),
        "content": detail.get("output", ""),
        "tasks_comments": comments,
    }

_running = True


def _handle_signal(signum, frame):
    global _running
    logger.info("Ricevuto segnale %s, arresto in corso...", signum)
    _running = False


def run_daemon():
    signal.signal(signal.SIGTERM, _handle_signal)
    signal.signal(signal.SIGINT, _handle_signal)

    cfg = load_config()
    if not config_is_complete(cfg):
        cfg = run_setup_wizard()

    client = MatildaClient(cfg["api_url"], cfg["api_key"])
    user_id = cfg["user_id"]
    poll_interval = cfg.get("poll_interval_seconds", DEFAULT_POLL_INTERVAL)
    conn = get_connection()

    machine = platform.node()
    ping_interval = 300  # 5 minuti
    last_ping = 0

    logger.info("Daemon avviato. Polling ogni %d secondi. Machine: %s", poll_interval, machine)

    while _running:
        # Ping Matilda ogni 5 minuti
        now = time.monotonic()
        if now - last_ping >= ping_interval:
            try:
                client.ping(machine)
                logger.debug("Ping inviato (%s)", machine)
            except Exception:
                logger.exception("Errore durante il ping")
            last_ping = now

        try:
            _poll_cycle(conn, client, user_id)
        except Exception:
            logger.exception("Errore nel ciclo di polling")

        for _ in range(poll_interval):
            if not _running:
                break
            time.sleep(1)

    conn.close()
    logger.info("Daemon terminato.")


def _poll_cycle(conn, client: MatildaClient, user_id: int):
    logger.info("Inizio ciclo di polling...")
    instructions = get_instructions()

    tasks = client.get_tasks(user_id)
    logger.info("Trovati %d task con deadline.", len(tasks))

    for t in tasks:
        if not _running:
            break
        task_id = t["id"]
        local = get_task(conn, task_id)

        if local and local["status"] in ("done", "skipped"):
            continue

        if local is None:
            _handle_new_task(conn, client, task_id, t, instructions)
        elif local["status"] == "info_requested":
            _handle_info_requested(conn, client, task_id, instructions)
        elif local["status"] == "pending":
            _handle_new_task(conn, client, task_id, t, instructions)


def _handle_new_task(conn, client: MatildaClient, task_id: int, summary: dict, instructions: str):
    logger.info("Nuovo task: #%d - %s", task_id, summary.get("title", ""))
    upsert_task(conn, task_id, summary.get("title", ""), summary.get("deadline", ""))

    raw_detail = client.get_task_detail(task_id)
    detail = extract_task_data(raw_detail)
    prompt = build_evaluation_prompt(instructions, detail)
    logger.info("Valutazione task #%d in corso...", task_id)
    response = run_opencode(prompt)
    logger.debug("Risposta valutazione per #%d: %s", task_id, response[:200])

    action, detail_text = parse_evaluation_response(response)
    _act_on_evaluation(conn, client, task_id, action, detail_text, detail, instructions)


def _handle_info_requested(conn, client: MatildaClient, task_id: int, instructions: str):
    raw_detail = client.get_task_detail(task_id)
    comments = raw_detail.get("tasks_comments", [])
    detail = extract_task_data(raw_detail)

    last_sent = get_last_comment_sent(conn, task_id)
    if last_sent is None:
        return

    last_sent_at = last_sent["sent_at"]
    new_user_comments = [
        c for c in comments
        if (c.get("service") or "") != "matilda-opencode"
        and c.get("created_at", "") > last_sent_at
    ]

    if not new_user_comments:
        logger.debug("Task #%d: nessun nuovo commento utente, skip.", task_id)
        return

    logger.info("Task #%d: %d nuovi commenti utente, rivalutazione...", task_id, len(new_user_comments))
    prompt = build_evaluation_prompt(instructions, detail)
    response = run_opencode(prompt)
    action, detail_text = parse_evaluation_response(response)
    _act_on_evaluation(conn, client, task_id, action, detail_text, detail, instructions)


def _act_on_evaluation(conn, client: MatildaClient, task_id: int, action: str, detail_text: str, task_detail: dict, instructions: str):
    if action == "SKIP":
        logger.info("Task #%d marcato come skipped: %s", task_id, detail_text)
        update_task_status(conn, task_id, "skipped", skip_reason=detail_text)

    elif action == "READY":
        logger.info("Task #%d pronto, avvio esecuzione...", task_id)
        update_task_status(conn, task_id, "running")
        _execute_task(conn, client, task_id, task_detail, instructions)

    elif action == "DOMANDE":
        if not detail_text.strip():
            logger.error("Task #%d: domande vuote da opencode, skip invio commento.", task_id)
            return
        logger.info("Task #%d richiede informazioni, invio domande...", task_id)
        client.post_comment(task_id, detail_text)
        record_comment(conn, task_id, "info_request")
        update_task_status(conn, task_id, "info_requested")


def _execute_task(conn, client: MatildaClient, task_id: int, task_detail: dict, instructions: str):
    prompt = build_execution_prompt(instructions, task_detail)
    logger.info("Esecuzione task #%d con OpenCode...", task_id)
    result = run_opencode(prompt)

    if not result.strip():
        logger.error("Task #%d: opencode ha restituito una risposta vuota, skip invio commento.", task_id)
        update_task_status(conn, task_id, "pending")
        return

    logger.info("Task #%d completato, invio risultati...", task_id)
    client.post_comment(task_id, result)
    record_comment(conn, task_id, "result")
    update_task_status(conn, task_id, "done")
