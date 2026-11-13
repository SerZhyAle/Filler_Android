# S0007 - Independent release preparation

**Ticket:** S0007
**Status:** BlockByOtherTask
**Status note:** Blocker: S0006 - complete the preceding Filler project step before this ticket.
**Priority:** 40
**Tier:** 3 - Moderate
**Complexity:** medium - release decisions and independent distribution
**Depends on:** S0006

## Goal

Prepare and verify an independently releasable Filler product after functional parity and device checks. Record the owner's choices for final application ID, signing, license, distribution channel, public remote and any site or privacy requirements before binding them.

## Acceptance

Document a dry-run of the selected independent release process and its required versioning, signing, documentation, privacy and store requirements. Do not create or expose signing secrets in the repository. No tag, upload, publication or external release without explicit authorization for that release.

### 3.3 Owner inputs (Approval gate)

- **Related tickets:** S0006.

### Owner decisions (2026-11-13)

Owner's order of 2026-11-13, relayed by the deviceinfo-mob session: "Сейчас то же делаем по Tourist_mob, а затем для Filler_mob !" - the public presence DeviceInfo, StreamsPlayer and Tourist got the same day (canon S0058). The owner accepted the recommendations table in one round of questions the same day; each one-way step had the owner's explicit yes.

| Input | Decision |
| --- | --- |
| Published application id | `com.sza.filler`, one id for the Android app and the watch app (S0013 answer B); bound to the owner's Play account by the creation of the console app. The build switch from `com.sza.filler.provisional`, which lifts the release guard of `phone/build.gradle.kts`, is this ticket's work |
| Signing | key directory `P:\ANDROID\Filler_credentials` outside the tree; Play App Signing with the product's own app signing key imported at the first upload, plus a separate upload key; the keys are the owner's step and do not exist yet |
| License | MIT: `LICENSE` added, the `SZA-LAY01` exemption closed |
| Channel | Google Play only, the Android app and the watch app in one listing; no sideload channel, so no install-trust contract |
| Public remote | `SerZhyAle/Filler_Android`, public, `PLAN/` public, issues on, wiki and projects off; README carries the privacy link, the contact and the AI-assistance line |
| Site and privacy page | GitHub Pages from `site/`: hand-written privacy pages in en, ru and uk with the vendored family kit, `sitemap.xml`, `robots.txt`; no landing yet, so the site root answers 404 and the listing website stays empty |
| Store name and branding | "Filler: Fill Storage Space" (the brand and the in-app name stay "Filler"); launcher glyph a memory card filled from the bottom; listing graphics rendered by `tools/store/render-store-assets.ps1` |
| Store settings | category Tools, contact `sza@ukr.net` |
| App content | Sign in details No; target audience 18 and over; Data safety no data collected or shared; IARC answered by the facts (`docs/play/PLAY_DATA_SAFETY.md`) |
| Account-level policy risk (S0016 question 1) | A: the listing is built around the single purpose and differs from FastMediaSorter's |
| Wear OS | the form factor is added in the console now; the review-policy opt-in, the screenshots and the bundles wait for the release |

Renamed the same day: the console flagged "Filler: Fill Free Space" and the short description ("free space") as keywords that indicate price ("app name: Should not use keywords that indicate price or promotion"; "Your app may not be promoted on Google Play because your short description does not meet the following guidelines"). The owner chose "Filler: Fill Storage Space"; the English short description now reads "empty space". The flags were gone after the save. The console's own header keeps the old name until the listing changes go out with the first review.
