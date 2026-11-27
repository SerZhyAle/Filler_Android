# Why Android warns about the Filler APK - and what to tap

<!-- languages -->
Languages: English - [Русский](INSTALL_TRUST-ru.md) - [Українська](INSTALL_TRUST-uk.md) - [Deutsch](INSTALL_TRUST-de.md) - [Italiano](INSTALL_TRUST-it.md) - [Español](INSTALL_TRUST-es.md) - [Français](INSTALL_TRUST-fr.md) - [Português](INSTALL_TRUST-pt.md) - [العربية](INSTALL_TRUST-ar.md) - [हिन्दी](INSTALL_TRUST-hi.md) - [বাংলা](INSTALL_TRUST-bn.md) - [اردو](INSTALL_TRUST-ur.md) - [简体中文](INSTALL_TRUST-zh.md)
<!-- /languages -->

Filler is a small free app from an independent developer. When you install the signed APK from GitHub Releases or
SourceForge instead of Google Play, Android shows a few prompts on the way in. Here is what they are, why they appear,
and exactly what to tap.

## 1. What the warning is

You may meet two things. The quoted words are what Android shows you:

- **"For security, your phone currently isn't allowed to install unknown apps from this source."** Android shows it the
  first time you open an APK from a browser or a file manager that you have not allowed to install apps. It has a
  **Settings** button. The screen behind it is named **Install unknown apps**, and the permission is per app: your
  browser, or your file manager.
- **"Play Protect doesn't recognize this app's developer"** (or **"App blocked to protect your device"**). Play Protect
  is the scanner built into Google Play services. It may offer **More details** and **Install anyway**, or **OK**.

The wording differs a little between Android versions and makers. These are the English strings; on a phone set to
another language Android shows its own translation of them (this page does not quote that translation, because it
cannot confirm it for every version).

## 2. Why it appears

- **Unknown apps.** Android treats every app that does not come from an installed store as coming from an "unknown
  source" and asks you once, for the app that opened the file. The prompt is about the source, not about Filler.
- **Play Protect.** The APK on GitHub Releases and SourceForge is signed with Filler's own release key, and it is not an
  install that Google Play counted, so Play Protect has no history for the developer. A new independent developer is
  unrecognised until installs accumulate; the warning does not mean the app is harmful, and it is not a mistake or a
  bug. As more people install, it may fade; it is not a promise.
- **Google Play.** The same app on Google Play is signed by Play App Signing and does not meet these prompts.
  If you want to skip them, install it from Google Play.

Before you install, you can compare the file with the `.sha256` file published beside it: they must hold the same
SHA-256 value. A different value means the download is damaged or not Filler's; delete it.

## 3. What to tap

1. Open the downloaded APK from your browser or file manager.
2. At **"For security, your phone currently isn't allowed to install unknown apps from this source."** tap
   **Settings**, switch on **Allow from this source** for that one app (your browser or file manager), and go back.
3. Tap **Install**. At **"Play Protect doesn't recognize this app's developer"** tap **More details**, then
   **Install anyway**. Filler asks for nothing else.
4. Afterwards switch **Allow from this source** off again: in Android settings open **Apps**, the app you used (browser or
   file manager), **Install unknown apps**. This is per app and reversible at any time.

Do not turn Play Protect off, and do not disable any other protection to install Filler: nothing here needs it. The
watch app is installed on the watch in the same way, through whichever tool you use to install watch APKs; the prompts
are the same.

## 4. What Filler never does

This list says the same as the [privacy policy](https://serzhyale.github.io/Filler_Android/privacy.html) and the
Google Play Data safety answers.

- It has no internet permission, so it sends nothing to anyone: not to the developer, not to a server, not to another app.
- It has no analytics, crash reporting, advertising or tracking code, and it creates no account.
- It does not open, read, copy or change your own files, and it deletes only the temporary files it wrote itself.
- It does not read your contacts, photos, messages, location or the data of other apps.
- The phone app asks for five permissions and the watch app for four, only to run a fill on time and keep it going with
  the screen dark; none of them gives access to your files or a network.
