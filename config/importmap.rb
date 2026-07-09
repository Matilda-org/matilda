# Pin npm packages by running ./bin/importmap

pin "application", preload: true
pin "@hotwired/turbo-rails", to: "turbo.min.js", preload: true
pin "@hotwired/stimulus", to: "https://ga.jspm.io/npm:@hotwired/stimulus@3.0.1/dist/stimulus.js"
pin "@hotwired/stimulus-loading", to: "stimulus-loading.js", preload: true
pin "bootstrap", to: "bootstrap.js", preload: true
pin_all_from "app/javascript/controllers", under: "controllers"
pin_all_from "app/javascript/libs", under: "libs"
pin "trix"
pin "@rails/actiontext", to: "actiontext.js"
pin "sortablejs", to: "https://ga.jspm.io/npm:sortablejs@1.15.6/modular/sortable.complete.esm.js"
pin "process", to: "https://ga.jspm.io/npm:@jspm/core@2.0.0-beta.24/nodelibs/browser/process-production.js"
pin "crypto-js", to: "https://ga.jspm.io/npm:crypto-js@4.2.0/index.js"
pin "crypto", to: "https://ga.jspm.io/npm:@jspm/core@2.0.0-beta.24/nodelibs/browser/crypto.js"
pin "stimulus-clipboard", to: "https://ga.jspm.io/npm:stimulus-clipboard@3.2.0/dist/stimulus-clipboard.es.js"
pin "@popperjs/core", to: "https://ga.jspm.io/npm:@popperjs/core@2.11.6/lib/index.js"
pin "flatpickr", to: "https://ga.jspm.io/npm:flatpickr@4.6.13/dist/esm/index.js"
