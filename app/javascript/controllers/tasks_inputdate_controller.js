import { Controller } from "@hotwired/stimulus"
import flatpickr from "flatpickr"

export default class extends Controller {
  connect() {
    // HACK: Per pulire DOM prima di cacharlo, aggiungo classe a input
    this.element.classList.add('turbo-before-cache-clean');

    // Inizializzazione di flatpickr con opzioni avanzate
    this.flatpickr = flatpickr(this.element, {
      altInput: true,
      altFormat: "d/m/Y",
      dateFormat: "Y-m-d",
      allowInput: true,
      enableTime: false,
      time_24hr: true,
      locale: {
        firstDayOfWeek: 1 // start week on Monday
      },
      onOpen: this.fetchTasksAndUpdateMarkers.bind(this),
      onMonthChange: this.fetchTasksAndUpdateMarkers.bind(this),
      onDayCreate: this.addMarkerPlaceholder.bind(this)
    });
    
    // Carica i dati iniziali
    this.fetchTasksAndUpdateMarkers();
  }

  disconnect() {
    this.flatpickr.destroy();
  }

  /**
   * Aggiunge un elemento div vuoto che fungerà da contenitore per il marker
   */
  addMarkerPlaceholder(dObj, dStr, fp, dayElem) {
    const marker = document.createElement('span');
    marker.classList.add('c-flatpickr-marker');
    
    // Corregge il problema del giorno avanti usando una data normalizzata in UTC
    const date = new Date(dayElem.dateObj);
    const year = date.getFullYear();
    const month = String(date.getMonth() + 1).padStart(2, '0');
    const day = String(date.getDate()).padStart(2, '0');
    const formattedDate = `${year}-${month}-${day}`;
    
    marker.dataset.date = formattedDate;
    dayElem.appendChild(marker);
  }

  /**
   * Recupera i dati dei tasks dall'API e aggiorna i marker
   */
  async fetchTasksAndUpdateMarkers() {
    try {
      // Ottiene il mese e l'anno correntemente visualizzati
      const currentMonth = this.flatpickr.currentMonth;
      const currentYear = this.flatpickr.currentYear;
      
      // Formatta mese e anno per l'API (mese è 0-based in JavaScript)
      const formattedMonth = String(currentMonth + 1).padStart(2, '0');
      const formattedYear = String(currentYear);
      
      // Chiama l'API con i parametri di mese e anno
      const response = await fetch(`/tasks/resume-per-inputdate?month=${formattedMonth}&year=${formattedYear}`);
      
      if (!response.ok) {
        throw new Error(`Errore API: ${response.status}`);
      }
      
      const data = await response.json();
 
      // Aggiorna i marker con i dati ricevuti
      this.updateMarkers(data);
    } catch (error) {
      console.error('Errore nel recupero dei task:', error);
    }
  }

  /**
   * Aggiorna i marker delle date in base ai dati ricevuti
   */
  updateMarkers(tasksData) {
    // Prima rimuove tutti i marker esistenti
    this.flatpickr.calendarContainer.querySelectorAll('.c-flatpickr-marker').forEach(marker => {
      marker.classList.remove('visible');
      marker.title = '';
    });
    
    // Poi aggiunge i nuovi marker
    console.log(tasksData);
    tasksData.forEach(task => {
      const marker = this.flatpickr.calendarContainer.querySelector(`.c-flatpickr-marker[data-date="${task.date}"]`);
      if (marker) {
        marker.className = 'c-flatpickr-marker visible';
        marker.classList.add(`bg-${task.color}`);

        // Aggiungi tooltip con il numero di task se necessario
        if (task.tasks_count > 0) {
          marker.title = `${task.count} task`;
        }
      }
    });
  }
}