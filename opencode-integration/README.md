# OpenCode Integration

Questo progetto è un programma da eseguire su un client con installato OpenCode che, interfacciandosi con le API di Matilda, riconosce le attività da svolgere e le fa eseguire agli agenti di OpenCode.

## Configurazione

La configurazione avviene tramite un file `config.json` che deve essere posizionato nella stessa directory del programma. Il file deve contenere le seguenti informazioni:

```json
{
  "matilda_api_url": "https://api.matilda.com",
  "matilda_api_key": "your_matilda_api_key"
}
```

## Api di Matilda

Le api di Matilda sono tutte autenticate tramite header `X-API-Key` con la chiave API fornita nella configurazione. Le principali API utilizzate sono:

- `GET /apis/tasks?completed=false&opencode_assignment=true`: Restistuisce la lista di task che devono essere eseguiti dagli agenti di OpenCode.
- `GET /apis/tasks/{task_id}`: Restituisce i dettagli di un task specifico.
- `POST /apis/tasks/{task_id}/comment`: Permette di aggiungere un commento a un task specifico per chiedere informazioni o aggiornare lo stato di avanzamaento del task.
- `POST /apis/opencode-integration/ping`: Permette di notificare a Matilda che il programma è attivo e funzionante.

### Struttura di un task

Un task è un oggetto con i seguenti campi:
```json
{
  "id": "task_id",
  "title": "Task title",
  "content": "Task content",
  "tasks_comments": [
    {
      "user_id": "user_id",
      "service": "service_name",
      "content": "comment content",
      "created_at": "2024-06-01T12:00:00Z",
      "updated_at": "2024-06-01T12:00:00Zm"
    }
  ],
  "created_at": "2024-06-01T12:00:00Z",
  "updated_at": "2024-06-01T12:00:00Z
}
```

### Parametri di un commento

Un commento può essere aggiunto a un task tramite l'API `POST /apis/tasks/{task_id}/comment` con i seguenti parametri:
```json
{
  "service": "service_name",
  "content": "comment content",
}
```

NOTE: service rappresenta il nome del servizio esterno che inserisce il commento e può essere utilizzato per distinguere i commenti inseriti da OpenCode da quelli inseriti da altri servizi o dagli utenti stessi.
Puoi commentare un task inviando la stringa `OpenCode` come valore del campo `service` per indicare che il commento è stato inserito da OpenCode.

## Funzionamento

Il programma funziona in loop continuo, eseguendo le seguenti operazioni:
- Inviare il ping a Matilda per notificare che il programma è attivo.
- Recuperare la lista dei task da eseguire tramite l'API `GET /apis/tasks?completed=false&opencode_assignment=true`.
- Per ogni task, recuperare i dettagli tramite l'API `GET /apis/tasks/{task_id}`.
- Gestire ogni task.

### Gestione di un task

La gestione di un task prevede comportamenti differenti:
- Se il task e in running da un agente di OpenCode, non fare nulla, aspetta il prossimo ciclo per vedere se ha finito.
- Se un task non è in running da un agente di OpenCode e l'ultimo commento non è di OpenCode, verifica l'output dell'agente e, se presente, commenta il task con l'output dell'agente. Se non è presente, avvia l'agente di OpenCode.
- Se un task non è in running da un agente di OpenCode e l'ultimo commento è di OpenCode, significa che l'agente ha finito e sta aspettando feedback dall'utente. In questo caso, non fare nulla, aspetta il prossimo ciclo per vedere se l'utente ha risposto.

### Integrazione con OpenCode

OpenCode ha una CLI utilizzabile per avviare gli agenti e recuperare i loro output.
La documentazione completa è disponibile a questo link: https://opencode.ai/docs/it/cli/.

### Informazioni custom

Dentro il programma può essere inserito un file INSTRUCTIONS.md che fonnisce informazioni custom da utilizzare per la gestione dei task. Il contenuto di questo file viene inviato agli agenti di OpenCode come contesto aggiuntivo per l'esecuzione dei task. Questo può essere utile per fornire istruzioni specifiche sull'ambiente di lavoro, sulle risorse disponibili o su eventuali restrizioni da rispettare durante l'esecuzione dei task.

### Gestione permessi

Nel caso in cui l'agente abbiamo problemi di permessi ad operare o altri errori di esecuzione che impediscono all'agente di completare il task, il programma deve stamparlo esplicitamente nei log e bloccarsi.