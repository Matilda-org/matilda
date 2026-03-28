import argparse
import logging
import os
import signal
import subprocess
import sys
from pathlib import Path

from .config import (
    BASE_DIR,
    DAEMON_LOG,
    AGENT_LOG,
    LOGS_DIR,
    PID_PATH,
    ensure_dirs,
    load_config,
    config_is_complete,
    run_setup_wizard,
)


def setup_logging(to_file: bool = False):
    ensure_dirs()
    logger = logging.getLogger("matilda-opencode")
    logger.setLevel(logging.DEBUG)

    fmt = logging.Formatter("%(asctime)s [%(levelname)s] %(message)s", datefmt="%Y-%m-%d %H:%M:%S")

    stderr_handler = logging.StreamHandler(sys.stderr)
    stderr_handler.setLevel(logging.INFO)
    stderr_handler.setFormatter(fmt)
    logger.addHandler(stderr_handler)

    if to_file:
        file_handler = logging.FileHandler(str(DAEMON_LOG))
        file_handler.setLevel(logging.DEBUG)
        file_handler.setFormatter(fmt)
        logger.addHandler(file_handler)


def cmd_start(args):
    if PID_PATH.exists():
        pid = PID_PATH.read_text().strip()
        try:
            os.kill(int(pid), 0)
            print(f"Daemon già in esecuzione (PID: {pid})")
            return
        except (OSError, ValueError):
            PID_PATH.unlink(missing_ok=True)

    ensure_dirs()
    # Launch daemon as background process
    daemon_script = Path(__file__).parent / "cli.py"
    proc = subprocess.Popen(
        [sys.executable, "-m", "src.cli", "_daemon"],
        stdout=open(DAEMON_LOG, "a"),
        stderr=subprocess.STDOUT,
        start_new_session=True,
        cwd=Path(__file__).resolve().parent.parent,
    )
    PID_PATH.write_text(str(proc.pid))
    print(f"Daemon avviato (PID: {proc.pid})")
    print(f"Log: {DAEMON_LOG}")


def cmd_stop(args):
    if not PID_PATH.exists():
        print("Daemon non in esecuzione.")
        return

    pid = PID_PATH.read_text().strip()
    try:
        os.kill(int(pid), signal.SIGTERM)
        print(f"Segnale di stop inviato al daemon (PID: {pid})")
    except (OSError, ValueError) as e:
        print(f"Impossibile fermare il daemon: {e}")
    finally:
        PID_PATH.unlink(missing_ok=True)


def cmd_status(args):
    if not PID_PATH.exists():
        print("Stato: Stopped")
        return

    pid = PID_PATH.read_text().strip()
    try:
        os.kill(int(pid), 0)
        print(f"Stato: Running (PID: {pid})")
    except (OSError, ValueError):
        print("Stato: Stopped (PID stale)")
        PID_PATH.unlink(missing_ok=True)

    if DAEMON_LOG.exists():
        lines = DAEMON_LOG.read_text().splitlines()
        last_lines = lines[-5:] if len(lines) >= 5 else lines
        print("\nUltimi log:")
        for line in last_lines:
            print(f"  {line}")


def cmd_logs(args):
    if not DAEMON_LOG.exists():
        print("Nessun log disponibile.")
        return

    follow = args.follow if hasattr(args, "follow") else False
    n = args.lines if hasattr(args, "lines") else 50

    if follow:
        # Mostra le ultime n righe, poi segui in tempo reale
        subprocess.run(["tail", "-n", str(n), "-f", str(DAEMON_LOG)])
    else:
        lines = DAEMON_LOG.read_text().splitlines()
        for line in lines[-n:]:
            print(line)


def cmd_daemon_internal(args):
    """Internal: runs the actual daemon loop (called by cmd_start)."""
    setup_logging(to_file=True)

    cfg = load_config()
    if not config_is_complete(cfg):
        print("Configurazione incompleta. Esegui prima: matilda-opencode start (in foreground)")
        sys.exit(1)

    from .daemon import run_daemon
    run_daemon()


def cmd_setup(args):
    cfg = load_config()
    if config_is_complete(cfg):
        print("Configurazione già presente. Vuoi sovrascriverla? (s/N): ", end="")
        resp = input().strip().lower()
        if resp != "s":
            print("Setup annullato.")
            return
    run_setup_wizard()


def cmd_run_foreground(args):
    """Run daemon in foreground (useful for debugging)."""
    setup_logging(to_file=True)
    cfg = load_config()
    if not config_is_complete(cfg):
        cfg = run_setup_wizard()
        setup_logging(to_file=True)

    from .daemon import run_daemon
    run_daemon()


def main():
    parser = argparse.ArgumentParser(
        prog="matilda-opencode",
        description="Daemon CLI per integrare Matilda con OpenCode",
    )
    sub = parser.add_subparsers(dest="command")

    sub.add_parser("start", help="Avvia il daemon in background")
    sub.add_parser("stop", help="Ferma il daemon")
    sub.add_parser("status", help="Mostra stato del daemon")

    logs_parser = sub.add_parser("logs", help="Mostra i log recenti")
    logs_parser.add_argument("-n", "--lines", type=int, default=50, help="Numero di righe da mostrare")
    logs_parser.add_argument("-f", "--follow", action="store_true", help="Segui i log in tempo reale (tail -f)")

    sub.add_parser("setup", help="Configura matilda-opencode")
    sub.add_parser("run", help="Esegui il daemon in foreground")
    sub.add_parser("_daemon", help=argparse.SUPPRESS)

    args = parser.parse_args()

    commands = {
        "start": cmd_start,
        "stop": cmd_stop,
        "status": cmd_status,
        "logs": cmd_logs,
        "setup": cmd_setup,
        "run": cmd_run_foreground,
        "_daemon": cmd_daemon_internal,
    }

    if args.command in commands:
        commands[args.command](args)
    else:
        parser.print_help()


if __name__ == "__main__":
    main()
