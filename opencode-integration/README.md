# OpenCode integration

Questa repository include un applicazione che si integra con OpenCode.
L'installazione avviene tramite uno script che, una volta eseguito, installa un comando `matilda-opencode start` che avvia l'esecuzione in background del processo di integrazione con OpenCode.
Il processo può essere fermato con il comando `matilda-opencode stop`, allo stesso modo può essere monitorato con `matilda-opencode status`.

## Primo avvio

Al primo avvio il programma chiede all'utente di inserire:
- url delle api di matilda
- api key di matilda
- user id di matilda

## Funzionamento

L'applicazione userà l'api di Matilda per:
- scaricare la lista di task non completati, con deadline, assegnati all'utente.
- commentare i task chiedendo informazioni utili per poterlo portare a termine.
- lanciare un agente opencode con le info prese dai commenti e dal task stesso per portare a termine il task.
- commentare il task con i risultati ottenuti dall'agente.

Opencode può essere chiamato utilizzand il comando `opencode` (https://opencode.ai/docs/) e permette, sia di usare modelli AI per portare a termine task, sia di usare un LLM per analizzare le risposte dell'utente e decidere se un task è da fare o no, o se servono più informazioni per portarlo a termine.

Il programma dovrà tenere un database locale per tenere traccia dei task già processati, in modo da non processarli più di una volta.
Allo stesso modo, se l'utente in un commento dice che il task non è da fare, il programma dovrà segnare il task come "non da fare" e non processarlo più.

Il programma deve installarsi in una directory dell'utente, ad esempio `~/.matilda-opencode/`, e deve essere eseguibile da qualsiasi directory tramite il comando `matilda-opencode`.

Dentro la directory ci deve essere un file INSTRUCTIONS.md dove l'utente può mettere info su come lavorare che verranno sempre fornite all'LLM (directory di lavoro, info su come usare git ecc.). 

