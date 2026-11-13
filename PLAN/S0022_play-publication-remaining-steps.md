# S0022_play-publication-remaining-steps

**Status:** Draft
**Created:** 2026-11-13
**Complexity:** medium - no source; ordered owner and release steps, several one-way

## 0. Owner request (verbatim)

Owner's rule (deviceinfo-mob session, 2026-11-13): "\"Что осталось до публикации\" это должен быть тикет в репозитори проекта, а не мне сюда"
Owner's order for this product (2026-11-13, relayed by the deviceinfo-mob session): "Сейчас то же делаем по Tourist_mob, а затем для Filler_mob !"
Owner, 2026-11-13, on the earlier "Filler" app found in the Play account: "я не понимаю как поступить правильно. старое приложение давно неработает и да - это новая его версия"

What remains before Filler is published on Google Play, as of 2026-11-13. Already done the same day on the owner's order (owner decisions of the same day, recorded in S0007 "Owner decisions (2026-11-13)": the recommendations table - application id com.sza.filler for the Android app and the watch app, MIT, Google Play only, repository Filler_Android with PLAN public, privacy pages in site/, store name "Filler: Fill Storage Space", category Tools, contact sza@ukr.net, Sign in details "No", graphics by script, S0016 question 1 answer A; the Play app created with Free and the declarations; target audience 18 and over; Data safety no data collected or shared; IARC by the facts):
- Public remote https://github.com/SerZhyAle/Filler_Android (MIT, issues on, wiki and projects off; commit 21edc3c is the whole tree, no earlier history) and its Pages site (workflow .github/workflows/pages.yml, run 43466526636 green): privacy.html, privacy-ru.html, privacy-uk.html, sitemap.xml, robots.txt and the assets answer 200; the site root answers 404 (no landing yet), so the repository has no homepage and the listing no website.
- Play Console app com.sza.filler ("Filler: Fill Storage Space", personal account 8446656778368889827, app 4975443931674740940, App, Free): every App content item saved, overview "You're all caught up" (privacy URL, Sign in details No, no ads, no advertising ID, not a government app, no financial features, no health features, target audience 18 and over, Data safety no data collected or shared, fresh IARC rating ESRB Everyone / ClassInd all ages); store settings Tools and sza@ukr.net; default listing en-US with ru-RU and uk translations, icon and feature graphic; Wear OS form factor added. Record: docs/play/PLAY_DATA_SAFETY.md "Console record" and docs/play/PLAY_LISTING.md "Console fields".
- Found during the run: the same account holds "Filler" ua.od.sza.filler (app 4975199606187837309), removed by Google on 2018-06-07 for "Not adhering to Google Play Developer Program policies"; its listing promised that deleted files "CAN NOT BE restored". The owner confirmed com.sza.filler is its new version and chose to create the new app as a draft.

Remaining, in order:
1. Commit and push the records written on 2026-11-13 after the first push (CLAUDE.md "Public presence", docs/play/PLAY_DATA_SAFETY.md "Console record", docs/play/PLAY_LISTING.md "Console fields", this ticket and the tickets filed the same day) - on the owner's word.
2. Before the first "Send for review": read Google's notice of 2018-06-07 about ua.od.sza.filler (the owner's mailbox; the console shows only the generic policy line), name the policy it cites, and check the new listing, graphics and app against it; the new texts make no erasure or unrecoverability claim. If the notice is unclear, ask Play support before the first submission.
3. The port itself (S0003 to S0006, S0008, S0009 and the watch tickets S0017 to S0020): the listing and the privacy pages describe the ordered product; when a port adds a permission, a library, a service or a network call, the privacy pages, docs/play/PLAY_DATA_SAFETY.md and the Data safety form change in the same edit (canon invariant 14).
4. S0007: switch phone/build.gradle.kts from com.sza.filler.provisional to com.sza.filler (lifts the release guard), the PACKAGE-VERSIONING band amendment for the published id, the tag shape, the keystore directory P:\ANDROID\Filler_credentials (the owner's step).
5. Phone screenshots (2 to 8, 16:9 or 9:16) and Wear OS screenshots for en-US, ru-RU and uk, from a real device check of the finished app (S0006, S0020).
6. Landing: filler-mob has none yet and no ticket builds it (DeviceInfo S0012 and Tourist S0026 are the models; the owner orders it). Once https://serzhyale.github.io/Filler_Android/ answers 200, set it as the website in Store settings and as the repository homepage (gh repo edit --homepage).
7. GitHub social preview: upload docs/github/social-preview-1280x640.png in the repository settings (the owner's browser).
8. Release side (S0007, owner's order only): store bundles of phone and wear, pre-flight verdict, first upload to internal testing with the app signing key import (one-way), the update proof, closed testing if the account requires it, countries (all, never narrowed) and rollout.
9. Wear OS opt-in and the Wear OS review policy (console Wear OS step 3; allowed only after the Wear screenshots and a Wear bundle on a testing track; one-way, owner's yes).
10. Production and review (one-way, owner's order only).
11. After the landing and the Play listing answer 200: the hub ticket (SITE-FAMILY-MAP row and hub card) and the footer-grid tickets filed in each map consumer become workable.
12. Account-level, not this app: "Declare your trader status" (due February 2027 for this account; the decision is the owner's).


## 1. Problem

What is wrong or missing, in the owner's terms. One paragraph; no class names, no file paths.

## 2. Done criteria

Each criterion is a command to run or an observation to repeat, so that "done" is something the next
reader can check rather than something the author believes.

- criterion one

## 3. Approach

### 3.1 Scope

What changes and what deliberately does not.

### 3.2 Open questions

Each question is answered here, or handed to a `Carrier:` token naming the ticket that will answer it.
A ticket does not close while a question is neither.

### 3.3 Owner inputs (Approval gate)

- **Related tickets:** none

Note of the same day: the store title was renamed from "Filler: Fill Free Space" to "Filler: Fill Storage Space" on the owner's choice, because the console flagged "free" in the title and the short description as a price keyword (S0007). The listing in the console was re-entered from docs/play after the rename and after the reserve sentence of S0005 (owner's order of the same day); the console header shows the old name until the listing changes are sent with the first review. Before the first review, re-check that the console text equals docs/play (a later edit of the sources is entered again).
