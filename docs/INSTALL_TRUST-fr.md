# Pourquoi Android affiche des avertissements pour l'APK de Filler - et ce qu'il faut toucher

<!-- languages -->
Langues : [English](INSTALL_TRUST.md) - [Русский](INSTALL_TRUST-ru.md) - [Українська](INSTALL_TRUST-uk.md) - [Deutsch](INSTALL_TRUST-de.md) - [Italiano](INSTALL_TRUST-it.md) - [Español](INSTALL_TRUST-es.md) - Français - [Português](INSTALL_TRUST-pt.md) - [العربية](INSTALL_TRUST-ar.md) - [हिन्दी](INSTALL_TRUST-hi.md) - [বাংলা](INSTALL_TRUST-bn.md) - [اردو](INSTALL_TRUST-ur.md) - [简体中文](INSTALL_TRUST-zh.md)
<!-- /languages -->

Filler est une petite application gratuite d'un développeur indépendant. Quand vous installez l'APK signé depuis GitHub Releases ou SourceForge au lieu de Google Play, Android affiche quelques messages au cours de l'installation. Voici ce qu'ils sont, pourquoi ils apparaissent et exactement ce qu'il faut toucher.

## 1. En quoi consiste l'avertissement

Vous pouvez rencontrer deux choses. Les mots entre guillemets sont ceux qu'Android affiche (textes anglais ; la traduction entre parenthèses ne sert qu'à la compréhension, ce n'est pas le texte de l'écran) :

- **"For security, your phone currently isn't allowed to install unknown apps from this source."** (pour des raisons de sécurité, votre téléphone n'est pas autorisé pour le moment à installer des applications inconnues depuis cette source). Android l'affiche la première fois que vous ouvrez un APK depuis un navigateur ou un gestionnaire de fichiers que vous n'avez pas autorisé à installer des applications. Ce message comporte un bouton **Settings** (Paramètres). L'écran qu'il ouvre s'appelle **Install unknown apps** (Installer des applications inconnues), et l'autorisation s'accorde application par application : à votre navigateur ou à votre gestionnaire de fichiers.
- **"Play Protect doesn't recognize this app's developer"** (Play Protect ne reconnaît pas le développeur de cette application) ou **"App blocked to protect your device"** (application bloquée pour protéger votre appareil). Play Protect est l'outil d'analyse intégré aux services Google Play. Il peut proposer **More details** (Plus de détails) et **Install anyway** (Installer quand même), ou **OK**.

La formulation varie un peu selon les versions d'Android et les fabricants. Ce sont les textes anglais ; sur un téléphone réglé sur une autre langue, Android affiche sa propre traduction de ces textes (cette page ne cite pas cette traduction, car elle ne peut pas la confirmer pour chaque version ; les traductions entre parenthèses ne servent qu'à la compréhension).

## 2. Pourquoi il apparaît

- **Applications inconnues.** Android considère que toute application qui ne provient pas d'une boutique installée provient d'une « source inconnue » et vous pose la question une fois, pour l'application qui a ouvert le fichier. Le message porte sur la source, pas sur Filler.
- **Play Protect.** L'APK proposé sur GitHub Releases et SourceForge est signé avec la clé de publication propre à Filler, et ce n'est pas une installation que Google Play a comptabilisée : Play Protect n'a donc aucun historique sur le développeur. Un nouveau développeur indépendant n'est pas reconnu tant que les installations ne se sont pas accumulées ; l'avertissement ne signifie pas que l'application est nuisible, et ce n'est ni une méprise ni un bogue. À mesure que davantage de personnes l'installent, il peut disparaître ; ce n'est pas une promesse.
- **Google Play.** La même application sur Google Play est signée par Play App Signing et ne déclenche pas ces messages. Si vous voulez les éviter, installez-la depuis Google Play.

Avant d'installer, vous pouvez comparer le fichier avec le fichier `.sha256` publié à côté : ils doivent correspondre à la même valeur SHA-256. Une valeur différente signifie que le téléchargement est endommagé ou que le fichier n'est pas celui de Filler ; supprimez-le.

## 3. Ce qu'il faut toucher

1. Ouvrez l'APK téléchargé depuis votre navigateur ou votre gestionnaire de fichiers.
2. Sur **"For security, your phone currently isn't allowed to install unknown apps from this source."** touchez **Settings**, activez **Allow from this source** (Autoriser cette source) pour cette seule application (votre navigateur ou votre gestionnaire de fichiers), puis revenez en arrière.
3. Touchez **Install** (Installer). Sur **"Play Protect doesn't recognize this app's developer"** touchez **More details**, puis **Install anyway**. Filler ne demande rien d'autre.
4. Ensuite, désactivez de nouveau **Allow from this source** : dans les paramètres Android, ouvrez **Apps** (Applications), l'application que vous avez utilisée (navigateur ou gestionnaire de fichiers), **Install unknown apps**. Ce réglage est propre à chaque application et réversible à tout moment.

Ne désactivez pas Play Protect ni aucune autre protection pour installer Filler : rien ici ne l'exige. L'application pour montre s'installe sur la montre de la même façon, avec l'outil que vous utilisez pour installer des APK sur la montre ; les messages sont les mêmes.

## 4. Ce que Filler ne fait jamais

Cette liste dit la même chose que la [politique de confidentialité](https://serzhyale.github.io/Filler_Android/privacy-fr.html) et les réponses de la rubrique Sécurité des données de Google Play.

- Il n'a pas l'autorisation d'accès à internet et n'envoie donc rien à personne : ni au développeur, ni à un serveur, ni à une autre application.
- Il ne contient aucun code d'analyse d'audience, de rapport de plantage, de publicité ou de pistage, et il ne crée aucun compte.
- Il n'ouvre, ne lit, ne copie ni ne modifie vos propres fichiers, et il ne supprime que les fichiers temporaires qu'il a lui-même écrits.
- L'application ne lit ni vos contacts, ni vos photos, ni vos messages, ni votre position, ni les données d'autres applications.
- L'application pour téléphone demande cinq autorisations et l'application pour montre quatre, uniquement pour exécuter un remplissage à l'heure et le faire continuer écran éteint ; aucune d'elles ne donne accès à vos fichiers ni à un réseau.

<!-- Rendered by tools/locale/render-translations.ps1 from INSTALL_TRUST.md and tools/locale/dictionaries/fr.json. Never edit it by hand. -->
