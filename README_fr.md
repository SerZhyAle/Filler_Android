# Filler pour Android

<!-- languages -->
Langues : [English](README.md) - [Русский](README_ru.md) - [Українська](README_uk.md) - [Deutsch](README_de.md) - [Italiano](README_it.md) - [Español](README_es.md) - Français - [Português](README_pt.md) - [العربية](README_ar.md) - [हिन्दी](README_hi.md) - [বাংলা](README_bn.md) - [اردو](README_ur.md) - [简体中文](README_zh.md)
<!-- /languages -->

Filler remplit l'espace libre d'un périphérique de stockage avec des fichiers temporaires, puis les supprime. Vous choisissez le stockage interne ou une carte mémoire, ou un dossier de celle-ci ; Filler affiche l'espace libre qu'il a mesuré et la part qu'il laisse libre pour le système, écrit jusqu'à la quantité que vous confirmez, en affichant la quantité écrite, le pourcentage et le temps restant, et supprime chaque fichier qu'il a écrit - après une exécution terminée, un arrêt, une erreur d'écriture, un redémarrage ou le retrait d'une carte mémoire. Vos propres fichiers restent intacts. Sur le téléphone, un remplissage s'exécute aussi selon une planification : à une heure fixée, application fermée, même après un redémarrage, en laissant libre le 1 Go habituel, au plus une fois par jour, chaque exécution étant inscrite dans un historique. Un seul identifiant d'application, `com.sza.filler`, couvre l'application Android et l'application Wear OS.

C'est le Filler de stockage local de FastMediaSorter devenu une application à part entière, et un produit indépendant : il ne partage aucun code applicatif avec les autres produits de la famille, uniquement les contrats publiés.

## Compilation

Avec le JDK et le SDK Android installés, `./gradlew :phone:assembleDebug :wear:assembleDebug` compile les APK de débogage de l'application pour téléphone et de l'application pour montre. D'où vient le produit : [docs/PLAN_BOOTSTRAP_HANDOFF.md](docs/PLAN_BOOTSTRAP_HANDOFF.md).

## Confidentialité

Le développeur ne reçoit aucune de vos données : pas de compte, pas d'analyse d'audience, pas de publicité, pas de pistage. Filler n'a aucun accès à internet, rien ne quitte donc l'appareil ; l'application pour téléphone ne demande que ce qui permet d'exécuter un remplissage planifié à l'heure, application fermée, et l'application pour montre que ce qui permet à un remplissage de continuer pendant que son écran est éteint. La politique complète : [politique de confidentialité](https://serzhyale.github.io/Filler_Android/privacy-fr.html).

## Installation de l'APK depuis GitHub Releases ou SourceForge

Les APK signés pour téléphone et montre publiés hors de Google Play amènent Android à demander d'autoriser les applications inconnues provenant d'une source, et peuvent afficher un avis de Play Protect au sujet du développeur. Le [guide d'installation](docs/INSTALL_TRUST-fr.md) explique ce qu'est chaque message, pourquoi il apparaît et exactement ce qu'il faut toucher. La même application sur Google Play est signée par Play App Signing et ne déclenche aucun de ces messages.

## Contact

E-mail [sza@ukr.net](mailto:sza@ukr.net), GitHub [SerZhyAle](https://github.com/SerZhyAle). Les questions et les signalements de bogues sont les bienvenus sous forme d'[issues GitHub](https://github.com/SerZhyAle/Filler_Android/issues).

Ce projet est développé avec une aide importante de l'IA ; l'auteur relit chaque modification.

## Licence

MIT - voir [LICENSE](LICENSE).

<!-- Rendered by tools/locale/render-translations.ps1 from README.md and tools/locale/dictionaries/fr.json. Never edit it by hand. -->
