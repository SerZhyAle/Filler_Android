# Filler für Android

<!-- languages -->
Sprachen: [English](README.md) - [Русский](README_ru.md) - [Українська](README_uk.md) - Deutsch - [Italiano](README_it.md) - [Español](README_es.md) - [Français](README_fr.md) - [Português](README_pt.md) - [العربية](README_ar.md) - [हिन्दी](README_hi.md) - [বাংলা](README_bn.md) - [اردو](README_ur.md) - [简体中文](README_zh.md)
<!-- /languages -->

Filler füllt den freien Platz eines Speichergeräts mit temporären Dateien und löscht sie dann wieder. Sie wählen den internen Speicher oder eine Speicherkarte oder einen Ordner darauf; Filler zeigt den gemessenen freien Speicher und den Teil, den es für das System freihält, schreibt bis zu der Menge, die Sie bestätigen, während die geschriebene Menge, der Prozentsatz und die verbleibende Zeit sichtbar sind, und löscht jede Datei, die es geschrieben hat - nach einem beendeten Durchlauf, einem Stopp, einem Schreibfehler, einem Neustart oder einer entfernten Speicherkarte. Ihre eigenen Dateien bleiben unverändert. Auf dem Telefon läuft ein Füllen auch nach Zeitplan: zur festgelegten Zeit bei geschlossener App, auch nach einem Neustart, wobei das übliche 1 GB frei bleibt, höchstens einmal am Tag, und jeder Lauf wird in einem Verlauf aufgelistet. Eine Anwendungs-ID, `com.sza.filler`, umfasst die Android-App und die Wear OS-App.

Es ist der Filler für lokalen Speicher aus FastMediaSorter als eigene App und ein unabhängiges Produkt: Es teilt keinen Anwendungscode mit den anderen Produkten der Familie, nur die veröffentlichten Verträge.

## Bauen

Wenn JDK und das Android SDK installiert sind, baut `./gradlew :phone:assembleDebug :wear:assembleDebug` die Debug-APKs der Telefon-App und der Uhr-App. Woher das Produkt stammt: [docs/PLAN_BOOTSTRAP_HANDOFF.md](docs/PLAN_BOOTSTRAP_HANDOFF.md).

## Datenschutz

Der Entwickler erhält keine Ihrer Daten: kein Konto, keine Analyse, keine Werbung, kein Tracking. Filler hat keinen Internetzugriff, daher verlässt nichts das Gerät; die Telefon-App fordert nur an, was ein geplantes Füllen bei geschlossener App pünktlich laufen lässt, und die Uhr-App nur, was ein Füllen bei dunklem Bildschirm weiterlaufen lässt. Die vollständige Erklärung: [Datenschutzerklärung](https://serzhyale.github.io/Filler_Android/privacy-de.html).

## APK aus GitHub Releases oder SourceForge installieren

Die außerhalb von Google Play veröffentlichten signierten APKs für Telefon und Uhr bringen Android dazu, nach der Erlaubnis für unbekannte Apps aus einer Quelle zu fragen, und können einen Play Protect-Hinweis zum Entwickler anzeigen. Was jeder Hinweis ist, warum er erscheint und worauf genau Sie tippen, steht in der [Installationsanleitung](docs/INSTALL_TRUST-de.md). Dieselbe App bei Google Play ist durch Play App Signing signiert und löst keinen dieser Hinweise aus.

## Kontakt

E-Mail [sza@ukr.net](mailto:sza@ukr.net), GitHub [SerZhyAle](https://github.com/SerZhyAle). Fragen und Fehlerberichte sind als [GitHub-Issues](https://github.com/SerZhyAle/Filler_Android/issues) willkommen.

Dieses Projekt wird mit umfangreicher KI-Unterstützung entwickelt; der Autor prüft jede Änderung.

## Lizenz

MIT - siehe [LICENSE](LICENSE).

<!-- Rendered by tools/locale/render-translations.ps1 from README.md and tools/locale/dictionaries/de.json. Never edit it by hand. -->
