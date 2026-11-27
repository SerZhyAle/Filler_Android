# Play Console - Data safety, App content and the content rating

Source of truth for the **App content answers** of Filler on Google Play: Data safety, the health, ads, government,
financial and sign-in declarations, the target audience and the IARC questionnaire, for the one Play app
`com.sza.filler` (the Android app and the Wear OS app share the application id, S0013 answer B). The forms live only in
the web console: the Play Developer API has no endpoint for them. Decide **here**, then answer in the console; never
decide inside the console.

Reconciled on 2026-11-13 against the tree of that day: the source manifests (`phone/src/main/AndroidManifest.xml`,
no permission, no `INTERNET`, `allowBackup="false"`; and, since S0019 on the same day, `wear/src/main/AndroidManifest.xml`:
`FOREGROUND_SERVICE`, `FOREGROUND_SERVICE_DATA_SYNC`, `WAKE_LOCK` and `POST_NOTIFICATIONS` for the run's foreground service,
no `INTERNET`, `allowBackup="false"`), `gradle/libs.versions.toml` (AndroidX
AppCompat, Material Components and the watch's wear-ongoing, no network, analytics, ads or Firebase library), and the upstream Filler that the
port tickets carry (FastMediaSorter S4521 as shipped in its package 48: the folder comes from the system folder picker
`OpenDocumentTree` with a persistable grant, the default destination is the app-specific external files directory,
free space is read with `StatFs`, no service, no network code). When a port ticket (S0003 to S0005, S0008, S0009, the
watch tickets S0017 to S0020) adds a permission, a library, a service or a network call, this file, the privacy pages
`site/privacy*.html` and the permission list change in the same edit (canon invariant 14), and the merged release
manifest is read again at the release.

Reconciled again on 2026-11-14 for the scheduled fill (S0025, owner decision Q1 of 2026-11-13): the phone manifest now
declares `RECEIVE_BOOT_COMPLETED`, `WAKE_LOCK`, `FOREGROUND_SERVICE`, `FOREGROUND_SERVICE_DATA_SYNC` and
`POST_NOTIFICATIONS`, removes the `ACCESS_NETWORK_STATE` that WorkManager merges, and still has no `INTERNET`; the catalog
gains AndroidX WorkManager (`work-runtime-ktx`), a local job scheduler with no network, analytics or ads code. The
schedules and their history live in an app-private file in `noBackupFilesDir` and never leave the device.

## The set that must say the same thing

- the privacy pages `site/privacy.html`, `site/privacy-ru.html`, `site/privacy-uk.html`
  (`https://serzhyale.github.io/Filler_Android/privacy.html`), hand-written, section 5 the permission statement;
- the source manifests of every source set (`phone/src/main` with the five of the scheduled fill, S0025, and
  `wear/src/main` with the four of the watch run, S0019);
- the listing texts [PLAY_LISTING.md](PLAY_LISTING.md) and their translations.

The permission counts in these, the application id and the interface-language sentence are compared with their sources by
`tools/site/check-site-facts.ps1` (S0039): the two manifests, `publishedApplicationId` and the `res/values*` folders of the
phone app. The addresses of the site that this record and the other holders carry are listed in
`docs/site-held-addresses.jsonl` and resolved against the pages by `tools/site/check-site.ps1`.

## What leaves the device, to whom, and the decision

The reading of Google's definitions (`https://support.google.com/googleplay/android-developer/answer/10787469`):
"collect" means transmitting data from the app off the user's device; data processed only on the device is not
disclosed.

| Flow | What leaves the device | To whom | Decision |
| --- | --- | --- | --- |
| Temporary files written into the chosen folder or the app's own folder | nothing: they are written and deleted on the device and hold no user data | nobody | Nothing to declare |
| The list of the run's temporary files, the settings (folder, reserve) | nothing: app-private storage, Android backup off | nobody | Nothing to declare |
| Free space and mount state of the chosen storage | nothing: read and shown on the device | nobody | Nothing to declare |
| Analytics, crash reports, advertising | nothing: none in the build, no `AD_ID`, no Firebase, no `INTERNET` | nobody | Nothing to declare |
| The watch run's foreground service, wake lock and progress notification (S0019) | nothing: they keep a user-started fill writing on the watch and show its progress there | nobody | Nothing to declare |
| The schedules of the scheduled fill and the history of their runs (S0025) | nothing: app-private storage, Android backup off | nobody | Nothing to declare |
| The scheduled fill's boot re-queue, wake lock, foreground service and notification (S0025) | nothing: they run a fill the user scheduled at its time on the device and show it there | nobody | Nothing to declare |

The facts allow one reading only: no data collected, no data shared (owner's acceptance of the recommendations table,
2026-11-13).

## The answers - `com.sza.filler`

| Item | Answer |
| --- | --- |
| Privacy policy | `https://serzhyale.github.io/Filler_Android/privacy.html` |
| Sign in details | No - no part of the app is restricted (owner decision of 2026-11-13) |
| Ads | No |
| Advertising ID | No - no `AD_ID`, ads, Firebase or analytics in the manifest or `gradle/libs.versions.toml` |
| Government apps | No |
| Financial features | My app doesn't provide any financial features |
| Health apps | My app does not have any health features - no `BODY_SENSORS`, `ACTIVITY_RECOGNITION`, health permission or step-counter sensor |
| Target audience | 18 and over (owner decision of 2026-11-13) |
| Data safety - collects or shares | No: "No data collection declared / No data shared with third parties" |
| Content rating | fresh IARC questionnaire, category All Other App Types, contact `sza@ukr.net`, every answer No (below) |

## Foreground service declaration (App content)

FILLER-0022 observed App content on 2026-11-17 and 2026-11-20. Both reads found the ten saved declarations
and no Foreground service permissions row. The answers below describe the two uses of `dataSync`.
Before an API upload, save and confirm the applicable declaration for both uses and record the evidence in
the [release record](PLAY_RELEASE_RECORD.md). If App content cannot show or save the declaration, stop before the
API write sequence and follow `GOOGLE-PLAY` 0.4 section 8C. Saving a Console form invalidates active edits.

Google Play asks an app that targets Android 14 or higher to declare each foreground-service type on the App content
page, with a description, the impact of interruption or deferral, and a demonstration video for each use.
The watch app declares one (S0019 and S0017 research note section 4). The answer to enter, with the console step
itself belonging to the publication steps (S0022):

| Item | Answer |
| --- | --- |
| Type | `dataSync` (`FOREGROUND_SERVICE_DATA_SYNC`) |
| Task | Local file processing: a fill of the watch's free space with temporary files, started by the user's tap on a
  confirmation, which keeps writing while the watch screen is dark and deletes the files when it finishes or is stopped |
| User impact if deferred or interrupted | the fill stops and its files are deleted; the user has to start it again |
| Started by | the user, from the app's confirmation screen; never by the system or another app (the service is not exported) |

The phone app declares the same type for the scheduled fill (S0025), on WorkManager's own foreground service. The second
answer, entered in the same console step:

| Item | Answer |
| --- | --- |
| Type | `dataSync` (`FOREGROUND_SERVICE_DATA_SYNC`) |
| Task | Local file processing: a fill of a folder's free space with temporary files at a time the user saved in a schedule
  and confirmed, which runs with the app closed and deletes the files when it finishes or is stopped |
| User impact if deferred or interrupted | the run is late or stops, its files are deleted and the history says so; the next slot runs as scheduled |
| Started by | the app's own scheduled job at the time the user chose; never by another app (no component is exported for it) |

## IARC answers

Answered by the facts (owner decision of 2026-11-13); a fresh questionnaire, never a copied rating id (canon invariant
15).

| Section | Answer and the fact behind it |
| --- | --- |
| Downloaded app | ratings-relevant content in the package: No - a storage utility with a folder choice, numbers and progress |
| User content sharing | users interact or exchange content: No - no network, no other users |
| Online content | content outside the package: No - no network access |
| Age-restricted products | No |
| Miscellaneous | location sharing: No; digital purchases: No; cash rewards or NFTs: No; web browser or search engine: No; news or educational: No |

## Console record (2026-11-13)

Filled in the owner's personal developer account (8446656778368889827) on the owner's order, with the owner's yes of
the same day for each one-way step (the package name, Free, the Developer Program Policies, the US export laws, the
IARC terms of use). Nothing is uploaded, nothing is sent for review.

### `com.sza.filler` (app 4975443931674740940, "Filler: Fill Storage Space")

| Item | State | Answer |
| --- | --- | --- |
| Privacy policy | saved | `https://serzhyale.github.io/Filler_Android/privacy.html` (answered 200 the same day) |
| Sign in details | saved | No - no part restricted |
| Ads | saved | No |
| Advertising ID | saved | No |
| Government apps | saved | No |
| Financial features | saved | My app doesn't provide any financial features; no documentation step asked |
| Health apps | saved | My app does not have any health features; no regional requirement asked |
| Target audience | saved | 18 and over (the "restrict minors" option left off) |
| Data safety | saved | collects or shares: No; the store preview reads "No data collection declared / No data shared with third parties" |
| Content rating | saved, fresh IARC questionnaire (submitted 2026-11-13 18:03) | category All Other App Types, contact `sza@ukr.net`, every answer No (the table above). Ratings seen on the summary: ClassInd all ages (L), ESRB Everyone |

Overview after these: "You're all caught up" (10 actioned declarations).

### An earlier app of the same name in the account

The account also holds "Filler" `ua.od.sza.filler` (app 4975199606187837309), last updated 2018-06-07 and **removed by
Google** on that date for "Not adhering to Google Play Developer Program policies" (rejected the same day; target API
notices of 2023 follow). Its listing promised that deleted files "CAN NOT BE restored" after a fill of the free space.
The owner confirmed on 2026-11-13 that `com.sza.filler` is its new version and chose to create the new app as a draft;
before the first "Send for review" the 2018 notice is read and the new listing is checked against it (the release
ticket's step). The current texts make no erasure or unrecoverability claim (FastMediaSorter S4521 non-goals).
