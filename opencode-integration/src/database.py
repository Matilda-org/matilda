import sqlite3
from datetime import datetime, timezone

from .config import DB_PATH, ensure_dirs

SCHEMA = """
CREATE TABLE IF NOT EXISTS tasks (
    id INTEGER PRIMARY KEY,
    status TEXT NOT NULL DEFAULT 'pending',
    title TEXT,
    deadline TEXT,
    first_seen_at DATETIME,
    last_processed_at DATETIME,
    skip_reason TEXT
);

CREATE TABLE IF NOT EXISTS comments_sent (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    task_id INTEGER NOT NULL,
    comment_id TEXT,
    sent_at DATETIME,
    type TEXT
);
"""


def get_connection() -> sqlite3.Connection:
    ensure_dirs()
    conn = sqlite3.connect(str(DB_PATH))
    conn.row_factory = sqlite3.Row
    conn.execute("PRAGMA journal_mode=WAL")
    conn.executescript(SCHEMA)
    return conn


def _now() -> str:
    return datetime.now(timezone.utc).isoformat()


def get_task(conn: sqlite3.Connection, task_id: int) -> sqlite3.Row | None:
    return conn.execute("SELECT * FROM tasks WHERE id = ?", (task_id,)).fetchone()


def upsert_task(conn: sqlite3.Connection, task_id: int, title: str, deadline: str, status: str = "pending"):
    existing = get_task(conn, task_id)
    if existing is None:
        conn.execute(
            "INSERT INTO tasks (id, status, title, deadline, first_seen_at, last_processed_at) VALUES (?, ?, ?, ?, ?, ?)",
            (task_id, status, title, deadline, _now(), _now()),
        )
    else:
        conn.execute(
            "UPDATE tasks SET title = ?, deadline = ?, last_processed_at = ? WHERE id = ?",
            (title, deadline, _now(), task_id),
        )
    conn.commit()


def update_task_status(conn: sqlite3.Connection, task_id: int, status: str, skip_reason: str | None = None):
    conn.execute(
        "UPDATE tasks SET status = ?, skip_reason = ?, last_processed_at = ? WHERE id = ?",
        (status, skip_reason, _now(), task_id),
    )
    conn.commit()


def record_comment(conn: sqlite3.Connection, task_id: int, comment_type: str, comment_id: str | None = None):
    conn.execute(
        "INSERT INTO comments_sent (task_id, comment_id, sent_at, type) VALUES (?, ?, ?, ?)",
        (task_id, comment_id, _now(), comment_type),
    )
    conn.commit()


def get_last_comment_sent(conn: sqlite3.Connection, task_id: int) -> sqlite3.Row | None:
    return conn.execute(
        "SELECT * FROM comments_sent WHERE task_id = ? ORDER BY sent_at DESC LIMIT 1",
        (task_id,),
    ).fetchone()
