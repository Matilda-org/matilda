#!/usr/bin/env bash
set -euo pipefail

INSTALL_DIR="$HOME/.matilda-opencode"
BIN_DIR="$HOME/.local/bin"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

echo "=== Installazione matilda-opencode ==="

# Verifica opencode
if ! command -v opencode &>/dev/null; then
    echo "ERRORE: 'opencode' non trovato nel PATH."
    echo "Installa opencode prima di procedere: https://opencode.ai/docs/"
    exit 1
fi

# Verifica Python
if ! command -v python3 &>/dev/null; then
    echo "ERRORE: python3 non trovato nel PATH."
    exit 1
fi

PYTHON_VERSION=$(python3 -c "import sys; print(f'{sys.version_info.major}.{sys.version_info.minor}')")
echo "Python: $PYTHON_VERSION"

# Crea directory di installazione
mkdir -p "$INSTALL_DIR/logs"
echo "Directory: $INSTALL_DIR"

# Ferma il daemon se in esecuzione
if [[ -f "$INSTALL_DIR/pid" ]]; then
    OLD_PID=$(cat "$INSTALL_DIR/pid")
    if kill -0 "$OLD_PID" 2>/dev/null; then
        echo "Daemon in esecuzione (PID: $OLD_PID), arresto..."
        kill "$OLD_PID" && rm -f "$INSTALL_DIR/pid"
        sleep 1
    fi
fi

# Copia il progetto
cp -r "$SCRIPT_DIR/src" "$INSTALL_DIR/"
cp "$SCRIPT_DIR/pyproject.toml" "$INSTALL_DIR/"

# Installa dipendenze
echo "Installazione dipendenze..."
python3 -m pip install --quiet httpx 2>/dev/null || python3 -m pip install --quiet --break-system-packages httpx

# Crea wrapper CLI
mkdir -p "$BIN_DIR"
cat > "$BIN_DIR/matilda-opencode" << WRAPPER
#!/usr/bin/env bash
cd "$INSTALL_DIR" && exec python3 -m src "\$@"
WRAPPER
chmod +x "$BIN_DIR/matilda-opencode"
echo "CLI: $BIN_DIR/matilda-opencode"

# Verifica PATH
if [[ ":$PATH:" != *":$BIN_DIR:"* ]]; then
    echo ""
    echo "ATTENZIONE: $BIN_DIR non è nel PATH."
    for rc in "$HOME/.bashrc" "$HOME/.zshrc"; do
        if [[ -f "$rc" ]]; then
            if ! grep -q "$BIN_DIR" "$rc"; then
                echo "export PATH=\"$BIN_DIR:\$PATH\"" >> "$rc"
                echo "Aggiunto a $rc"
            fi
        fi
    done
    echo "Ricarica la shell o esegui: export PATH=\"$BIN_DIR:\$PATH\""
fi

# Crea INSTRUCTIONS.md se non esiste
if [[ ! -f "$INSTALL_DIR/INSTRUCTIONS.md" ]]; then
    cat > "$INSTALL_DIR/INSTRUCTIONS.md" << 'INSTRUCTIONS'
# Istruzioni per l'agente

## Directory di lavoro
working_dir: ~/projects/

## Git
- Crea sempre un branch feature prima di lavorare
- Usa commit atomici con messaggi descrittivi
- Non fare push direttamente su main

## Note aggiuntive
<!-- Aggiungi qui qualsiasi altra info utile per l'agente -->
INSTRUCTIONS
    echo "File istruzioni: $INSTALL_DIR/INSTRUCTIONS.md"
fi

# Permessi config
if [[ -f "$INSTALL_DIR/config.json" ]]; then
    chmod 600 "$INSTALL_DIR/config.json"
fi

echo ""
echo "=== Installazione completata ==="
echo ""
echo "Per iniziare:"
echo "  matilda-opencode setup    # Configura API Matilda"
echo "  matilda-opencode start    # Avvia il daemon"
echo "  matilda-opencode status   # Verifica stato"
echo "  matilda-opencode logs     # Vedi i log"
