# ☂ Matilda - Project manager for better companies

[![Deploy on Railway](https://railway.com/button.svg)](https://railway.com/deploy/matilda?referralCode=aVun_Y&utm_medium=integration&utm_source=template&utm_campaign=generic)

Matilda è un'**applicazione web per la gestione dei progetti**, sviluppata in Ruby on Rails.

Matilda è un progetto open source e può essere utilizzata liberamente. È possibile contribuire al progetto segnalando bug, suggerendo nuove funzionalità o contribuendo con codice.

<img src="./docs/preview.gif" alt="Matilda preview" width="100%">

## 🧑‍💻 Installazione

L'applicazione può essere installata in locale o su un server cloud tramite Docker.
L'applicazione non richiede specifiche dipendenze, ma è consigliato l'uso di PostgreSQL come database.

### Requisiti

- Docker
- Docker Compose

### Installazione

```bash
# Clona il repository
git clone
cd matilda
# Crea il docker-compose.yml (e modifica le variabili d'ambiente se necessario)
cp docker-compose.example.yml docker-compose.yml
# Builda l'immagine Docker
docker compose build
# Crea il database ed esegui le migrazioni
docker compose run matilda bin/rails db:migrate
# Crea un utente admin per l'accesso al pannello
docker compose run matilda bin/rails create_default_admin
# Crea dati di default per iniziare a usare l'applicazione
docker compose run matilda bin/rails create_default_data
# Avvia il container
docker compose up
```

Accedi al pannello con le credenziali:
- Email: `admin@mail.com`
- Password: `Password1!`

NOTE: Per motivi di sicurezza, si consiglia di modificare l'email e la password dell'utente admin dopo il primo accesso.

### Configurazione

Per eseguire l'applicazione correttamente è necessario configurare le seguenti variabili d'ambiente:

#### Impostazioni Rails

- `RAILS_ENV`: Ambiente di esecuzione dell'applicazione (default: `development`)
- `RAILS_SERVE_STATIC_FILES`: Serve i file statici (default: `disabled`, options: `enabled/disabled`)
- `RAILS_LOG_TO_STDOUT`: Invia i log a STDOUT (default: `disabled`, options: `enabled/disabled`)
- `RAILS_LOG_LEVEL`: Livello di log dell'applicazione (default: `error`)
- `RAILS_SERVERLESS_MODE`: Modalità serverless (default: `disabled`, options: `enabled/disabled`)

#### Impostazioni di sicurezza

- `SECRET_KEY_BASE`: Chiave segreta per la generazione dei token di autenticazione
- `ACTIVE_RECORD_ENCRYPTION_PRIMARY_KEY`: Chiave primaria per la crittografia dei dati sensibili (default: unsafe)
- `ACTIVE_RECORD_ENCRYPTION_DETERMINISTIC_KEY`: Chiave deterministica per la crittografia dei dati sensibili (default: unsafe)
- `ACTIVE_RECORD_ENCRYPTION_KEY_DERIVATION_SALT`: Sale per la derivazione della chiave di crittografia (default: unsafe)

#### Configurazione del database

- `DATABASE_URL`: URL di connessione al database PostgreSQL (Se non specificato, l'applicazione utilizzerà SQLite3)

#### Configurazione SMTP per l'invio delle email

- `SMTP_USER_NAME`: Nome utente per l'invio delle email (se non specificato, l'applicazione non invierà email)
- `SMTP_PASSWORD`: Password per l'invio delle email (se non specificato, l'applicazione non invierà email)
- `SMTP_ADDRESS`: Indirizzo del server SMTP (se non specificato, l'applicazione non invierà email)
- `SMTP_DOMAIN`: Dominio del server SMTP (se non specificato, l'applicazione non invierà email)
- `SMTP_PORT`: Porta del server SMTP (se non specificato, l'applicazione non invierà email)

#### Configurazione del bucket S3 compatibile

- `BUCKET_ACCESS_KEY`: Chiave di accesso per il bucket S3 (se non specificato, l'applicazione utilizzerà il filesystem locale)
- `BUCKET_ACCESS_KEY_SECRET`: Chiave segreta per il bucket S3 (se non specificato, l'applicazione utilizzerà il filesystem locale)
- `BUCKET_REGION`: Regione del bucket S3 (se non specificato, l'applicazione utilizzerà il filesystem locale)
- `BUCKET_NAME`: Nome del bucket S3 (se non specificato, l'applicazione utilizzerà il filesystem locale)

#### Configurazione di Matilda

- `MATILDA_MAIL_FROM`: Indirizzo email del mittente (default  `Matilda <noreply@mail.com>`)
- `MATILDA_HOST`: Indirizzo host dell'applicazione (default `matilda.local`)

### Configurazione tramite credentials

In alternativa, per mantenere lo standard di Ruby on Rails, è possibile utilizzare il file `config/credentials.yml.enc` per memorizzare la configurazione. Per farlo, eseguire il comando:

```bash
EDITOR="nano" rails credentials:edit
```

Di seguito è riportato un esempio di file `credentials.yml.enc`:

```yaml
# config/credentials.yml.enc
secret_key_base: example_secret_key_base

active_record_encryption:
  primary_key: example_primary_key
  deterministic_key: example_deterministic_key
  key_derivation_salt: example_key_derivation_salt

smtp:
  user_name: user_name@mail.com
  password: example_password
  domain: example.com
  address: mail.example.com
  port: 587

bucket:
  region: eu-central-1
  access_key_id: example_access_key_id
  access_key_secret: example_access_key_secret
  bucket: example_bucket
```

## 💬 Integrazioni

### Slack

Matilda può essere integrata con Slack per creare automaticamente i canali dei progetti e inviare notifiche e aggiornamenti. Per configurare l'integrazione con Slack, è necessario creare un'app Slack e inserire i seguenti parametri di configurazione:

```json
{
    "display_information": {
        "name": "Matilda",
        "description": "Project manager for better companies",
        "background_color": "#181d45"
    },
    "features": {
        "bot_user": {
            "display_name": "Matilda",
            "always_online": false
        },
        "slash_commands": [
            {
                "command": "/search_attachment",
                "url": "https://MATILDA_HOST/slack/search-project-attachment",
                "description": "Search project attachments",
                "should_escape": false
            },
            {
                "command": "/search_log",
                "url": "https://MATILDA_HOST/slack/search-project-log",
                "description": "Search project logs",
                "should_escape": false
            }
        ]
    },
    "oauth_config": {
        "scopes": {
            "bot": [
                "incoming-webhook",
                "channels:manage",
                "chat:write",
                "commands",
                "groups:write",
                "users:read"
            ]
        }
    },
    "settings": {
        "org_deploy_enabled": false,
        "socket_mode_enabled": false,
        "token_rotation_enabled": false
    }
}
```

## 💻 Sviluppo

Per contribuire allo sviluppo di Matilda, è possibile seguire i seguenti passaggi:
1. Fork del repository
2. Creare un branch per la nuova funzionalità (`git checkout -b feat/my-new-feature`)
3. Commit delle modifiche (`git commit -am 'Add some feature'`)
4. Push del branch (`git push origin feat/my-new-feature`)
5. Creare una pull request

### Installazione in locale

#### Requisiti

- Ruby 3.2.0

#### Passaggi di installazione

```bash
# Clona il repository
git clone
cd matilda
# Installa le dipendenze
bundle install
# Crea il database
rails db:create
# Esegui le migrazioni
rails db:migrate
# Esegui i seed
rails db:seed
# Avvia il server
rails server
```

Accedi al pannello con le credenziali:
- Email: `admin@mail.com`
- Password: `Password1!`

#### Simulazione installazione da zero

```bash
rails db:drop
rails db:create
rails db:migrate
rails create_default_admin
rails create_default_data
rails server
```

### Testing

L'applicazione utilizza Minitest come framework di testing e SimpleCov per la copertura del codice. Per eseguire i test, è possibile utilizzare il comando:

```bash
rails test
```

Il comando genererà un report di copertura del codice nella cartella `coverage`.
