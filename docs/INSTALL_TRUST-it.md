# Perché Android avvisa sull'APK di Filler - e che cosa toccare

<!-- languages -->
Lingue: [English](INSTALL_TRUST.md) - [Русский](INSTALL_TRUST-ru.md) - [Українська](INSTALL_TRUST-uk.md) - [Deutsch](INSTALL_TRUST-de.md) - Italiano - [Español](INSTALL_TRUST-es.md) - [Français](INSTALL_TRUST-fr.md) - [Português](INSTALL_TRUST-pt.md) - [العربية](INSTALL_TRUST-ar.md) - [हिन्दी](INSTALL_TRUST-hi.md) - [বাংলা](INSTALL_TRUST-bn.md) - [اردو](INSTALL_TRUST-ur.md) - [简体中文](INSTALL_TRUST-zh.md)
<!-- /languages -->

Filler è una piccola app gratuita di uno sviluppatore indipendente. Quando installi l'APK firmato da GitHub Releases o SourceForge invece che da Google Play, Android mostra alcune richieste lungo il percorso. Ecco che cosa sono, perché compaiono e che cosa toccare esattamente.

## 1. Che cos'è l'avviso

Potresti incontrare due cose. Le parole tra virgolette sono quelle che Android ti mostra (testi in inglese; la traduzione tra parentesi serve solo a capire e non è il testo dello schermo):

- **"For security, your phone currently isn't allowed to install unknown apps from this source."** (Per motivi di sicurezza, al momento il tuo telefono non può installare app sconosciute da questa origine.) Android lo mostra la prima volta che apri un APK da un browser o da un file manager a cui non hai consentito di installare app. Ha un pulsante **Settings** (Impostazioni). La schermata che si apre si chiama **Install unknown apps** (Installa app sconosciute), e l'autorizzazione è per singola app: il tuo browser o il tuo file manager.
- **"Play Protect doesn't recognize this app's developer"** (Play Protect non riconosce lo sviluppatore di questa app) oppure **"App blocked to protect your device"** (App bloccata per proteggere il dispositivo). Play Protect è lo scanner integrato in Google Play Services. Può proporre **More details** (Altri dettagli) e **Install anyway** (Installa comunque), oppure **OK**.

La formulazione cambia leggermente tra versioni di Android e produttori. Queste sono le stringhe in inglese; su un telefono impostato in un'altra lingua Android ne mostra una propria traduzione (questa pagina non cita quella traduzione, perché non può confermarla per ogni versione).

## 2. Perché compare

- **App sconosciute.** Android considera ogni app che non arriva da uno store installato come proveniente da un'«origine sconosciuta» e te lo chiede una volta, per l'app che ha aperto il file. La richiesta riguarda l'origine, non Filler.
- **Play Protect.** L'APK su GitHub Releases e SourceForge è firmato con la chiave di rilascio propria di Filler e non è un'installazione conteggiata da Google Play, quindi Play Protect non ha uno storico per lo sviluppatore. Un nuovo sviluppatore indipendente resta non riconosciuto finché non si accumulano installazioni; l'avviso non significa che l'app sia dannosa, e non è un errore né un difetto. Con l'aumentare delle installazioni potrebbe scomparire; non è una promessa.
- **Google Play.** La stessa app su Google Play è firmata tramite Play App Signing e non incontra queste richieste. Se vuoi evitarle, installala da Google Play.

Prima di installare puoi confrontare il file con il file `.sha256` pubblicato accanto: devono contenere lo stesso valore SHA-256. Un valore diverso significa che il download è danneggiato o non è di Filler; eliminalo.

## 3. Che cosa toccare

1. Apri l'APK scaricato dal browser o dal file manager.
2. Su **"For security, your phone currently isn't allowed to install unknown apps from this source."** (Per motivi di sicurezza, al momento il tuo telefono non può installare app sconosciute da questa origine.) tocca **Settings** (Impostazioni), attiva **Allow from this source** (Consenti da questa origine) solo per quell'app (il tuo browser o file manager) e torna indietro.
3. Tocca **Install** (Installa). Su **"Play Protect doesn't recognize this app's developer"** (Play Protect non riconosce lo sviluppatore di questa app) tocca **More details** (Altri dettagli), poi **Install anyway** (Installa comunque). Filler non chiede altro.
4. Dopo, disattiva di nuovo **Allow from this source** (Consenti da questa origine): nelle impostazioni di Android apri **Apps** (App), l'app che hai usato (browser o file manager), **Install unknown apps** (Installa app sconosciute). Vale per la singola app ed è reversibile in qualsiasi momento.

Non disattivare Play Protect e non disabilitare nessun'altra protezione per installare Filler: qui nulla lo richiede. L'app per orologio si installa sull'orologio nello stesso modo, con lo strumento che usi per installare gli APK sull'orologio; le richieste sono le stesse.

## 4. Che cosa Filler non fa mai

Questo elenco dice le stesse cose dell'[informativa sulla privacy](https://serzhyale.github.io/Filler_Android/privacy-it.html) e delle risposte sulla Sicurezza dei dati di Google Play.

- Non ha l'autorizzazione per Internet, quindi non invia nulla a nessuno: né allo sviluppatore, né a un server, né a un'altra app.
- Non contiene codice di analisi, segnalazione di arresti anomali, pubblicità o tracciamento e non crea alcun account.
- Non apre, non legge, non copia e non modifica i tuoi file, ed elimina solo i file temporanei che ha scritto lui stesso.
- Non legge i tuoi contatti, le foto, i messaggi, la posizione né i dati di altre app.
- L'app per telefono richiede cinque autorizzazioni e l'app per orologio quattro, solo per eseguire un riempimento in orario e farlo continuare a schermo spento; nessuna di esse dà accesso ai tuoi file o a una rete.

<!-- Rendered by tools/locale/render-translations.ps1 from INSTALL_TRUST.md and tools/locale/dictionaries/it.json. Never edit it by hand. -->
