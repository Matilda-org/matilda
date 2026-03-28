import json
import os
import stat
from pathlib import Path

BASE_DIR = Path.home() / ".matilda-opencode"
CONFIG_PATH = BASE_DIR / "config.json"
INSTRUCTIONS_PATH = BASE_DIR / "INSTRUCTIONS.md"
DB_PATH = BASE_DIR / "db.sqlite"
LOGS_DIR = BASE_DIR / "logs"
PID_PATH = BASE_DIR / "pid"
DAEMON_LOG = LOGS_DIR / "daemon.log"
AGENT_LOG = LOGS_DIR / "agent.log"

DEFAULT_POLL_INTERVAL = 300

INSTRUCTIONS_TEMPLATE = """# Istruzioni per l'agente

## Directory di lavoro
working_dir: ~/projects/

## Git
- Crea sempre un branch feature prima di lavorare
- Usa commit atomici con messaggi descrittivi
- Non fare push direttamente su main

## Note aggiuntive
<!-- Aggiungi qui qualsiasi altra info utile per l'agente -->
"""


def ensure_dirs():
    BASE_DIR.mkdir(exist_ok=True)
    LOGS_DIR.mkdir(exist_ok=True)


def load_config() -> dict | None:
    if not CONFIG_PATH.exists():
        return None
    with open(CONFIG_PATH) as f:
        return json.load(f)


def save_config(cfg: dict):
    ensure_dirs()
    with open(CONFIG_PATH, "w") as f:
        json.dump(cfg, f, indent=2)
    os.chmod(CONFIG_PATH, stat.S_IRUSR | stat.S_IWUSR)


def config_is_complete(cfg: dict | None) -> bool:
    if cfg is None:
        return False
    return all(cfg.get(k) for k in ("api_url", "api_key", "user_id"))


def run_setup_wizard() -> dict:
    print("Benvenuto in matilda-opencode!\n")
    api_url = input("Inserisci l'URL delle API di Matilda: ").strip().rstrip("/")
    api_key = input("Inserisci la tua API key: ").strip()
    user_id_str = input("Inserisci il tuo User ID: ").strip()
    user_id = int(user_id_str)

    cfg = {
        "api_url": api_url,
        "api_key": api_key,
        "user_id": user_id,
        "poll_interval_seconds": DEFAULT_POLL_INTERVAL,
    }
    save_config(cfg)
    print(f"\nConfigurazione salvata in {CONFIG_PATH}")

    if not INSTRUCTIONS_PATH.exists():
        INSTRUCTIONS_PATH.write_text(INSTRUCTIONS_TEMPLATE)
        print(f"File istruzioni creato in {INSTRUCTIONS_PATH}")

    return cfg


def get_instructions() -> str:
    if INSTRUCTIONS_PATH.exists():
        return INSTRUCTIONS_PATH.read_text()
    return ""
