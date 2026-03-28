# matilda-opencode — Specifiche tecniche

> Versione 1.0 — Documento di riferimento per l'implementazione

---

## 1. Panoramica del progetto

`matilda-opencode` è un daemon CLI che integra l'API di Matilda con OpenCode. Il programma scarica periodicamente i task assegnati all'utente con deadline, raccoglie le informazioni necessarie tramite commenti, delega l'esecuzione a un agente OpenCode e pubblica i risultati su Matilda. Gira in background come processo gestito e si installa nella home dell'utente.

---

## 2. Struttura della directory di installazione

```
~/.matilda-opencode/
├── config.json           # Configurazione (url API, api key, user ID)
├── INSTRUCTIONS.md       # Istruzioni personalizzate per l'LLM
├── db.sqlite             # Database locale SQLite
├── logs/
│   ├── daemon.log        # Log del processo principale
│   └── agent.log         # Log delle esecuzioni OpenCode
└── pid                   # PID del processo in background
```

### File INSTRUCTIONS.md

L'utente può personalizzare questo file con informazioni che vengono sempre fornite all'LLM: directory di lavoro, convenzioni git, stack tecnologico, preferenze operative. Viene incluso in ogni prompt inviato a OpenCode.

Template iniziale generato dall'installer:

```markdown
# Istruzioni per l'agente

## Directory di lavoro
working_dir: ~/projects/

## Git
- Crea sempre un branch feature prima di lavorare
- Usa commit atomici con messaggi descrittivi
- Non fare push direttamente su main

## Note aggiuntive
<!-- Aggiungi qui qualsiasi altra info utile per l'agente -->
```

---

## 3. Installazione

Lo script di installazione deve:

1. Copiare il binario/script principale in `~/.matilda-opencode/`
2. Creare un wrapper `matilda-opencode` in `~/.local/bin/` (o `/usr/local/bin/` se root)
3. Assicurarsi che `~/.local/bin` sia nel `PATH` (aggiungere a `.bashrc` / `.zshrc` se assente)
4. Creare la directory `~/.matilda-opencode/` con i file iniziali
5. Impostare `chmod 600` su `config.json`
6. Verificare che `opencode` sia installato e disponibile nel PATH

---

## 4. Comandi CLI

| Comando | Descrizione |
|---|---|
| `matilda-opencode start` | Avvia il daemon in background |
| `matilda-opencode stop` | Ferma il daemon |
| `matilda-opencode status` | Mostra stato, PID e ultimo log |
| `matilda-opencode logs` | Mostra i log recenti |

### Gestione del processo background

```bash
# Avvio
nohup matilda-opencode-daemon >> ~/.matilda-opencode/logs/daemon.log 2>&1 &
echo $! > ~/.matilda-opencode/pid

# Stop
kill $(cat ~/.matilda-opencode/pid) && rm ~/.matilda-opencode/pid

# Status
PID=$(cat ~/.matilda-opencode/pid)
kill -0 $PID 2>/dev/null && echo "Running (PID: $PID)" || echo "Stopped"
```

---

## 5. Primo avvio — setup interattivo

Al primo avvio (o se `config.json` è incompleto), il programma avvia un wizard interattivo:

```
Benvenuto in matilda-opencode!

Inserisci l'URL delle API di Matilda: https://matilda.example.com
Inserisci la tua API key: ****
Inserisci il tuo User ID: 42

Configurazione salvata in ~/.matilda-opencode/config.json
```

Struttura di `config.json`:

```json
{
  "api_url": "https://matilda.example.com",
  "api_key": "...",
  "user_id": 42,
  "poll_interval_seconds": 300
}
```

---

## 6. API di Matilda

### Endpoints

```
GET  /tasks?user_id={user_id}&completed=false&with_deadline=true
GET  /tasks/{id}
POST /tasks/{id}/comment
```

Ogni chiamata include l'header:

```
Authorization: Bearer {api_key}
```

### GET /tasks

Restituisce la lista dei task dell'utente. I parametri rilevanti:

| Parametro | Valore | Effetto |
|---|---|---|
| `user_id` | ID utente | Filtra per utente |
| `completed` | `false` | Solo task non completati |
| `with_deadline` | qualsiasi valore truthy | Solo task con deadline |

Risposta: array JSON con i campi base del task. Ordinati per `deadline DESC`, limite 100.

### GET /tasks/{id}

Restituisce il dettaglio completo di un task. Include le associazioni:

| Associazione | Utilizzo |
|---|---|
| `project` | Nome e dettagli del progetto per contestualizzare il task |
| `tasks_comments` | Storico commenti con `content`, `service`, `user_id`, `created_at` |
| `tasks_checks` | Checklist del task |
| `procedures_items` | Procedure a cui il task appartiene |
| `procedures_as_item` | Procedure che includono questo task come step |
| `tasks_tracks` | Tracciamenti temporali |
| `tasks_followers` | Utenti che seguono il task |

Campi rilevanti del task:

| Campo | Tipo | Note |
|---|---|---|
| `id` | integer | Chiave primaria |
| `title` | string | Titolo del task |
| `output` | string | Descrizione dell'output atteso |
| `deadline` | date | Scadenza |
| `completed` | boolean | Stato completamento |
| `unresolved` | boolean | Task con problemi aperti |
| `project_id` | integer | Progetto associato |

### POST /tasks/{id}/comment

Pubblica un commento sul task.

Request body:

```json
{
  "content": "Testo del commento",
  "service": "matilda-opencode"
}
```

Il campo `service` identifica i commenti prodotti dal daemon, permettendo di distinguerli dalle risposte umane nella logica di analisi.

Response:

```json
{}
```

In caso di errore: `{ "errors": ["..."] }` con status `422`.

---

## 7. Schema del database locale (SQLite)

```sql
CREATE TABLE tasks (
  id INTEGER PRIMARY KEY,        -- ID task su Matilda
  status TEXT NOT NULL DEFAULT 'pending',
  title TEXT,
  deadline TEXT,
  first_seen_at DATETIME,
  last_processed_at DATETIME,
  skip_reason TEXT               -- Valorizzato solo se status = 'skipped'
);

-- status possibili:
--   'pending'        → task visto per la prima volta, non ancora elaborato
--   'info_requested' → commento con domande già inviato, in attesa di risposta
--   'running'        → agente OpenCode in esecuzione
--   'done'           → task completato con successo
--   'skipped'        → task marcato come "non da fare"

CREATE TABLE comments_sent (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  task_id INTEGER NOT NULL,
  comment_id TEXT,               -- Riferimento futuro se l'API restituisce l'ID
  sent_at DATETIME,
  type TEXT                      -- 'info_request' | 'result'
);
```

---

## 8. Flusso principale del daemon

Il daemon esegue un loop con polling periodico (default: 300 secondi).

```
LOOP PRINCIPALE
│
├── GET /tasks?user_id=X&completed=false&with_deadline=true
│
└── Per ogni task nella lista:
    │
    ├── [status = 'done' o 'skipped' in DB]
    │    └── skip, nessuna azione
    │
    ├── [task non presente in DB → primo avvistamento]
    │    ├── Salva in DB con status = 'pending'
    │    ├── GET /tasks/{id}  ← fetch dettaglio completo
    │    ├── Chiedi all'LLM: "Ho abbastanza info per eseguire questo task?"
    │    │    ├── SKIP    → Aggiorna status = 'skipped', salva motivo, fine
    │    │    ├── READY   → Lancia agente OpenCode (vedi §9)
    │    │    │             Posta risultati come commento
    │    │    │             Aggiorna status = 'done'
    │    │    └── DOMANDE → Posta commento con le domande
    │    │                   Aggiorna status = 'info_requested'
    │    └── Aggiorna last_processed_at
    │
    └── [status = 'info_requested' in DB]
         ├── GET /tasks/{id}  ← fetch commenti aggiornati
         ├── Estrai commenti dell'utente arrivati dopo l'ultimo commento del daemon
         │    (filtra: service != 'matilda-opencode' AND created_at > ultimo commento inviato)
         ├── Se nessun commento nuovo → skip, attendi prossimo ciclo
         └── Chiedi all'LLM: "Con queste risposte, posso procedere?"
              ├── SKIP    → Aggiorna status = 'skipped', salva motivo, fine
              ├── READY   → Lancia agente OpenCode (vedi §9)
              │             Posta risultati come commento
              │             Aggiorna status = 'done'
              └── DOMANDE → Posta nuovo commento con domande aggiuntive
                             (status rimane 'info_requested')
```

---

## 9. Integrazione con OpenCode

OpenCode viene invocato tramite il comando `opencode` disponibile nel PATH. Documentazione: https://opencode.ai/docs/

### Prompt per valutare se si hanno abbastanza informazioni

```
[contenuto di ~/.matilda-opencode/INSTRUCTIONS.md]

## Task da valutare

Titolo: {task.title}
Output atteso: {task.output}
Deadline: {task.deadline}
Progetto: {task.project.name}

## Checklist
{task.tasks_checks}

## Commenti esistenti
{task.tasks_comments}

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
(elenca le informazioni mancanti necessarie per procedere)
```

### Prompt per eseguire il task

```
[contenuto di ~/.matilda-opencode/INSTRUCTIONS.md]

## Task da eseguire

Titolo: {task.title}
Output atteso: {task.output}
Deadline: {task.deadline}
Progetto: {task.project.name}

## Checklist
{task.tasks_checks}

## Informazioni raccolte
{task.tasks_comments}

---

Porta a termine il task. Al termine produci un report strutturato con:
- Riepilogo di cosa è stato fatto
- File creati o modificati (se applicabile)
- Eventuali problemi riscontrati o decisioni prese
```

L'output dell'agente viene catturato e postato integralmente come commento sul task con `service: "matilda-opencode"`.

### Parsing della risposta LLM per la valutazione

| Output inizia con | Azione |
|---|---|
| `READY` | Procedi con l'esecuzione del task |
| `SKIP -` | Salva il motivo, imposta status `skipped`, non processare più |
| `DOMANDE` | Estrai le domande, postale come commento, imposta status `info_requested` |

---

## 10. Rilevamento risposte utente nei commenti

I commenti prodotti dal daemon hanno `service = "matilda-opencode"`. Per rilevare le risposte dell'utente su un task in stato `info_requested`:

1. Recupera tutti i `tasks_comments` tramite `GET /tasks/{id}`
2. Trova il `created_at` dell'ultimo commento con `service = "matilda-opencode"`
3. I commenti rilevanti sono quelli con:
   - `service` diverso da `"matilda-opencode"` (o null)
   - `created_at` successivo all'ultimo commento del daemon

Se non esistono commenti nuovi dell'utente, il task viene saltato fino al prossimo ciclo di polling.

---

## 11. Stack tecnologico consigliato

| Componente | Scelta consigliata |
|---|---|
| Linguaggio | Python 3.10+ o Node.js 18+ |
| Database | SQLite (`sqlite3` stdlib Python / `better-sqlite3` Node) |
| HTTP client | `httpx` (Python) o `got` (Node) |
| CLI parsing | `argparse` (Python) o `commander` (Node) |
| Config | JSON |
| Daemon management | Fork nativo + PID file |
| Logging | File rotante + stderr con livelli DEBUG / INFO / ERROR |

---

## 12. Sicurezza

- `config.json` salvato con permessi `600` (`chmod 600`) — leggibile solo dall'utente
- Il file PID risiede in `~/.matilda-opencode/pid`, non in `/tmp`
- L'output di OpenCode viene troncato a una lunghezza massima prima di essere postato come commento (es. 10.000 caratteri), con nota se troncato
- Il daemon non esegue mai codice proveniente dai commenti direttamente: tutto passa attraverso OpenCode

---

## 13. Estensioni future (opzionali)

- `matilda-opencode config` per modificare la configurazione interattivamente
- Supporto a più profili Matilda (multi-account)
- Notifiche desktop (`notify-send` su Linux, `osascript` su macOS)
- Filtri configurabili per priorità, etichette o progetto
- Retry automatico con backoff in caso di fallimento dell'agente
- `matilda-opencode logs --task {id}` per filtrare i log per task specifico