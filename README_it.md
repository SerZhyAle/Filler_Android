# Filler per Android

<!-- languages -->
Lingue: [English](README.md) - [Русский](README_ru.md) - [Українська](README_uk.md) - [Deutsch](README_de.md) - Italiano - [Español](README_es.md) - [Français](README_fr.md) - [Português](README_pt.md) - [العربية](README_ar.md) - [हिन्दी](README_hi.md) - [বাংলা](README_bn.md) - [اردو](README_ur.md) - [简体中文](README_zh.md)
<!-- /languages -->

Filler riempie lo spazio libero di un dispositivo di archiviazione con file temporanei e poi li elimina di nuovo. Scegli la memoria interna o una scheda di memoria, o una cartella su di essa; Filler mostra lo spazio libero misurato e la parte che lascia libera per il sistema, scrive fino alla quantità che confermi, tenendo in vista quanto è stato scritto, la percentuale e il tempo rimanente, ed elimina ogni file che ha scritto - dopo un riempimento completato, un'interruzione, un errore di scrittura, un riavvio o la rimozione di una scheda di memoria. I tuoi file restano come sono. Sul telefono un riempimento viene eseguito anche su pianificazione: all'orario fissato con l'app chiusa, anche dopo un riavvio, lasciando libero il consueto 1 GB, al massimo una volta al giorno, con ogni esecuzione elencata in una cronologia. Un solo identificativo dell'applicazione, `com.sza.filler`, copre l'app Android e l'app Wear OS.

È il Filler per la memoria locale di FastMediaSorter come app a sé, ed è un prodotto indipendente: non condivide codice applicativo con gli altri prodotti della famiglia, solo i contratti pubblicati.

## Compilazione

Con il JDK e l'Android SDK installati, `./gradlew :phone:assembleDebug :wear:assembleDebug` compila gli APK di debug dell'app per telefono e dell'app per orologio. Da dove viene il prodotto: [docs/PLAN_BOOTSTRAP_HANDOFF.md](docs/PLAN_BOOTSTRAP_HANDOFF.md).

## Privacy

Lo sviluppatore non riceve alcun tuo dato: nessun account, nessuna analisi, nessuna pubblicità, nessun tracciamento. Filler non ha accesso a Internet, quindi nulla lascia il dispositivo; l'app per telefono chiede solo ciò che permette a un riempimento pianificato di essere eseguito in orario con l'app chiusa, e l'app per orologio solo ciò che fa continuare un riempimento mentre lo schermo è spento. L'informativa completa: [informativa sulla privacy](https://serzhyale.github.io/Filler_Android/privacy-it.html).

## Installare l'APK da GitHub Releases o SourceForge

Gli APK firmati per telefono e orologio pubblicati al di fuori di Google Play fanno sì che Android chieda di consentire app sconosciute da una sola origine e possono mostrare un avviso di Play Protect sullo sviluppatore. Che cos'è ogni richiesta, perché compare e che cosa toccare esattamente è spiegato nella [guida all'installazione](docs/INSTALL_TRUST-it.md). La stessa app su Google Play è firmata tramite Play App Signing e non incontra nessuna di queste richieste.

## Contatti

E-mail [sza@ukr.net](mailto:sza@ukr.net), GitHub [SerZhyAle](https://github.com/SerZhyAle). Domande e segnalazioni di bug sono benvenute come [issue su GitHub](https://github.com/SerZhyAle/Filler_Android/issues).

Questo progetto è sviluppato con un ampio aiuto dell'IA; l'autore rivede ogni modifica.

## Licenza

MIT - vedi [LICENSE](LICENSE).

<!-- Rendered by tools/locale/render-translations.ps1 from README.md and tools/locale/dictionaries/it.json. Never edit it by hand. -->
