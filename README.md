# Filler for Android

Filler fills the free space of a storage device with temporary files and then deletes them again. You choose built-in
storage or a memory card, or a folder on it; Filler shows the free space it measured and the part it keeps free for the
system, writes up to the amount you confirm, with how much is written, the percentage and the time left in view, and
deletes every file it wrote - after a finished run, a stop, a write error, a restart or a removed memory card. Your own
files stay as they are. On the phone a fill also runs on a schedule: at a set time with the app closed, even after a
restart, keeping the usual 1 GB free, at most once a day, with every run listed in a history. One application id, `com.sza.filler`, covers the Android app and the Wear OS app.

It is the local-storage Filler of FastMediaSorter as its own app, and an independent product: it shares no application
code with the other products of the family, only the published contracts.

## Status

The phone module builds with its own Gradle configuration; the build commands are in `CLAUDE.md`. The ticket store and
the release plan are in `PLAN/` and use `tools/harness.ps1`. Where the product came from:
[docs/PLAN_BOOTSTRAP_HANDOFF.md](docs/PLAN_BOOTSTRAP_HANDOFF.md).

## Privacy

The developer receives none of your data: no account, no analytics, no advertising, no tracking. Filler has no
internet access, so nothing leaves the device; the phone app asks only for what runs a scheduled fill on time with the
app closed, and the watch app only for what keeps a fill going while its screen is dark. The full policy, in English, Russian and
Ukrainian: [privacy policy](https://serzhyale.github.io/Filler_Android/privacy.html).

## Installing the APK from GitHub Releases or SourceForge

The signed phone and watch APKs published outside Google Play make Android ask to allow unknown apps from one source and
may show a Play Protect notice about the developer. What each prompt is, why it appears and exactly what to tap, in
[English](docs/INSTALL_TRUST.md), [Russian](docs/INSTALL_TRUST-ru.md) and [Ukrainian](docs/INSTALL_TRUST-uk.md). The
same app on Google Play is signed by Play App Signing and meets none of these prompts.

## Contact

Email [sza@ukr.net](mailto:sza@ukr.net), GitHub [SerZhyAle](https://github.com/SerZhyAle). Questions and bug reports are
welcome as [GitHub issues](https://github.com/SerZhyAle/Filler_Android/issues).

This project is developed with heavy AI assistance; the author reviews every change.

## License

MIT - see [LICENSE](LICENSE).
