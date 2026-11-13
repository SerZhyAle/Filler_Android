# Play listing - English

The text of the three store fields of `com.sza.filler` on Google Play. The Russian text is
[PLAY_LISTING-ru.md](PLAY_LISTING-ru.md) and the Ukrainian [PLAY_LISTING-uk.md](PLAY_LISTING-uk.md); the headings are the
console's field names in all three. Limits: title 30 characters, short description 80, full description 4000. Store
name "Filler: Fill Storage Space", category Tools, contact `sza@ukr.net`: owner decisions of 2026-11-13 (S0007). The title
and the short description carry no "free": the console flagged "Free Space" in both as a keyword that indicates price
(owner's rename of the same day, from "Filler: Fill Free Space"). The text
is built around the single purpose and differs from FastMediaSorter's listing (S0016 question 1, answer A). It does not
claim what the upstream spec rules out (FastMediaSorter S4521 non-goals): no capacity verification, no data recovery,
no guaranteed secure erasure, no network or cloud storage. Written as a shipped, present-tense fact (canon invariant
17); the text goes public only with the first published release.

## Title

Filler: Fill Storage Space

## Short description

Fill a storage's empty space with temporary files, then delete them again

## Full description

Filler fills the free space of a storage device with temporary files and then deletes them again. Your own files stay as they are.

Choose where
Pick built-in storage or a memory card, or a folder on it, in the Android folder picker, or start at once in Filler's own folder. Filler shows the free space it measured and the part it keeps free for the system. By default it keeps 1 GB free; before a run you can lower this to as little as 10 MB.

Fill and follow it
One confirmation names the folder, the amount and the part kept free before anything is written. During the run you see how much is written, the percentage, the write speed and the time left. You can stop at any moment, and the files written so far are deleted.

Clean up, always
Filler deletes only the files it wrote itself, never anything else. It keeps a list of them, so after a stop, a write error, a restart or a removed memory card it offers to delete what is left as soon as the storage is back.

Any device, and the watch
Filler works with touch, keyboard, mouse and D-pad, in portrait and landscape, on phones, tablets and other Android devices, and on Wear OS watches.

Privacy
Filler asks for no permission and has no internet access: no account, no analytics, no advertising, no tracking. Nothing leaves your device.

Interface languages: English, Russian and Ukrainian.

## Console fields (2026-11-13)

Entered in the Play Console for `com.sza.filler` (app 4975443931674740940) from this file and its two translations: App
name, short and full description in en-US (default), ru-RU and uk, re-entered the same day after the rename and the
reserve sentence of S0005 (the counters read 26, 73, 1348 / 26, 74, 1438 / 26, 73, 1405). Store settings: category Tools, contact email `sza@ukr.net`, website empty until a landing at
`https://serzhyale.github.io/Filler_Android/` answers 200, then the landing, never the repository. Graphics:
`icon-512.png` and `feature-graphic-1024x500.png` beside this file, render targets of
`tools/store/render-store-assets.ps1`; ru-RU and uk fall back to them. Screenshots are not uploaded. Form factors: Wear
OS added (its three steps - Wear screenshots, a Wear bundle on a testing track, the review-policy opt-in - wait for the
release); Android XR stays Active by Google's default. The App content answers are in
[PLAY_DATA_SAFETY.md](PLAY_DATA_SAFETY.md), "Console record".
