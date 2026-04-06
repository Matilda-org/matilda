# Matilda OpenCode

Integrazione tra Matilda e OpenCode per lo sviluppo autonomo di task e progetti.
Il programma richiede che OpenCode sia installato e configurato correttamente nel dispositivo.

## Configurazione

La configurazione è definita da un file `config.json` che specifica i dettagli dell'integrazione che specifica:
- `matilda_api_url`: L'URL dell'API di Matilda.
- `matilda_api_key`: La chiave API per autenticarsi con Matilda.
- `workdir`: La directory di lavoro dove OpenCode opererà.

## Utilizzo

```bash
chmod +x start.sh
./start.sh
```