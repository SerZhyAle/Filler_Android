# Warum Android vor der Filler-APK warnt - und worauf Sie tippen

<!-- languages -->
Sprachen: [English](INSTALL_TRUST.md) - [Русский](INSTALL_TRUST-ru.md) - [Українська](INSTALL_TRUST-uk.md) - Deutsch - [Italiano](INSTALL_TRUST-it.md) - [Español](INSTALL_TRUST-es.md) - [Français](INSTALL_TRUST-fr.md) - [Português](INSTALL_TRUST-pt.md) - [العربية](INSTALL_TRUST-ar.md) - [हिन्दी](INSTALL_TRUST-hi.md) - [বাংলা](INSTALL_TRUST-bn.md) - [اردو](INSTALL_TRUST-ur.md) - [简体中文](INSTALL_TRUST-zh.md)
<!-- /languages -->

Filler ist eine kleine kostenlose App eines unabhängigen Entwicklers. Wenn Sie die signierte APK aus GitHub Releases oder SourceForge statt aus Google Play installieren, zeigt Android unterwegs ein paar Hinweise an. Hier steht, welche das sind, warum sie erscheinen und worauf genau Sie tippen.

## 1. Was die Warnung ist

Ihnen können zwei Dinge begegnen. Die zitierten Wörter zeigt Android Ihnen an (englische Texte; die Übersetzung in Klammern dient nur dem Verständnis und ist nicht der Bildschirmtext):

- **"For security, your phone currently isn't allowed to install unknown apps from this source."** (Aus Sicherheitsgründen darf Ihr Telefon derzeit keine unbekannten Apps aus dieser Quelle installieren.) Android zeigt dies an, wenn Sie zum ersten Mal eine APK aus einem Browser oder Dateimanager öffnen, dem Sie das Installieren von Apps nicht erlaubt haben. Es gibt eine Schaltfläche **Settings** (Einstellungen). Der Bildschirm dahinter heißt **Install unknown apps** (Unbekannte Apps installieren), und die Berechtigung gilt pro App: für Ihren Browser oder Ihren Dateimanager.
- **"Play Protect doesn't recognize this app's developer"** (Play Protect erkennt den Entwickler dieser App nicht) oder **"App blocked to protect your device"** (App zum Schutz Ihres Geräts blockiert). Play Protect ist der in die Google Play-Dienste eingebaute Scanner. Er bietet möglicherweise **More details** (Weitere Details) und **Install anyway** (Trotzdem installieren) oder **OK** an.

Der Wortlaut unterscheidet sich etwas zwischen Android-Versionen und Herstellern. Dies sind die englischen Texte; auf einem Telefon mit einer anderen Sprache zeigt Android seine eigene Übersetzung davon an (diese Seite zitiert diese Übersetzung nicht, weil sie sie nicht für jede Version bestätigen kann).

## 2. Warum sie erscheint

- **Unbekannte Apps.** Android behandelt jede App, die nicht aus einem installierten Store stammt, als aus einer „unbekannten Quelle“ kommend und fragt Sie einmal, und zwar für die App, die die Datei geöffnet hat. Der Hinweis betrifft die Quelle, nicht Filler.
- **Play Protect.** Die APK auf GitHub Releases und SourceForge ist mit dem eigenen Release-Schlüssel von Filler signiert und ist keine Installation, die Google Play gezählt hat, daher hat Play Protect keine Vorgeschichte zum Entwickler. Ein neuer unabhängiger Entwickler bleibt unbekannt, bis sich Installationen ansammeln; die Warnung bedeutet nicht, dass die App schädlich ist, und sie ist weder ein Irrtum noch ein Fehler. Wenn mehr Menschen die App installieren, kann sie verschwinden; versprochen ist das nicht.
- **Google Play.** Dieselbe App bei Google Play ist durch Play App Signing signiert und löst diese Hinweise nicht aus. Wenn Sie sie überspringen möchten, installieren Sie die App aus Google Play.

Vor der Installation können Sie die Datei mit der daneben veröffentlichten Datei `.sha256` vergleichen: Beide müssen denselben SHA-256-Wert enthalten. Ein anderer Wert bedeutet, dass der Download beschädigt ist oder nicht von Filler stammt; löschen Sie ihn.

## 3. Worauf Sie tippen

1. Öffnen Sie die heruntergeladene APK aus Ihrem Browser oder Dateimanager.
2. Bei **"For security, your phone currently isn't allowed to install unknown apps from this source."** (Aus Sicherheitsgründen darf Ihr Telefon derzeit keine unbekannten Apps aus dieser Quelle installieren.) tippen Sie auf **Settings** (Einstellungen), schalten **Allow from this source** (Aus dieser Quelle zulassen) für diese eine App (Ihren Browser oder Dateimanager) ein und gehen zurück.
3. Tippen Sie auf **Install** (Installieren). Bei **"Play Protect doesn't recognize this app's developer"** (Play Protect erkennt den Entwickler dieser App nicht) tippen Sie auf **More details** (Weitere Details) und dann auf **Install anyway** (Trotzdem installieren). Filler verlangt sonst nichts.
4. Schalten Sie danach **Allow from this source** (Aus dieser Quelle zulassen) wieder aus: Öffnen Sie in den Android-Einstellungen **Apps** (Anwendungen), die verwendete App (Browser oder Dateimanager), **Install unknown apps** (Unbekannte Apps installieren). Dies gilt pro App und lässt sich jederzeit rückgängig machen.

Schalten Sie Play Protect nicht aus und deaktivieren Sie keinen anderen Schutz, um Filler zu installieren: Nichts hier erfordert das. Die Uhr-App wird auf dieselbe Weise auf der Uhr installiert, mit dem Werkzeug, mit dem Sie APKs auf der Uhr installieren; die Hinweise sind dieselben.

## 4. Was Filler niemals macht

Diese Liste sagt dasselbe wie die [Datenschutzerklärung](https://serzhyale.github.io/Filler_Android/privacy-de.html) und die Angaben zur Datensicherheit bei Google Play.

- Es hat keine Internetberechtigung und sendet daher niemandem etwas: weder an den Entwickler noch an einen Server noch an eine andere App.
- Es enthält keinen Code für Analyse, Absturzberichte, Werbung oder Tracking und erstellt kein Konto.
- Es öffnet, liest, kopiert oder ändert Ihre eigenen Dateien nicht und löscht nur die temporären Dateien, die es selbst geschrieben hat.
- Sie liest weder Ihre Kontakte, Fotos, Nachrichten oder Ihren Standort noch die Daten anderer Apps.
- Die Telefon-App fordert fünf Berechtigungen an und die Uhr-App vier, nur damit ein Füllen pünktlich läuft und bei dunklem Bildschirm weiterläuft; keine davon gewährt Zugriff auf Ihre Dateien oder ein Netzwerk.

<!-- Rendered by tools/locale/render-translations.ps1 from INSTALL_TRUST.md and tools/locale/dictionaries/de.json. Never edit it by hand. -->
