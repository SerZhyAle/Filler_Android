# Listing brief - the Filler's store entry against FastMediaSorter's

One page, written under S0016 on 2026-11-13. It compares the two Google Play entries and states what the Play policy text
says about them. The decision it serves is already taken: the listing is built around the single purpose and differs from
FastMediaSorter's (S0016 question 1, answer A, recorded in S0007 "Owner decisions (2026-11-13)"; the texts are
`docs/play/PLAY_LISTING.md`, `-ru` and `-uk`). FastMediaSorter's entry was read from its listing source
(`play/listing/` of the checkout at HEAD `1a3ddca74`), not from the live store page.

## 1. The two entries side by side

| | FastMediaSorter (`com.sza.fastmediasorter`) | Filler (`com.sza.filler`) |
| --- | --- | --- |
| Title | Fast Media Sorter & Organizer | Filler: Fill Storage Space |
| Short description | Android device shell: home screen, media player, live TV, full file manager | Fill a storage's empty space with temporary files, then delete them again |
| Start screen | the listing leads with the home-screen shell (first screenshot slot `launcher` in FastMediaSorter's `play/listing/captions.json`; pillar 1 of its `docs/POSITIONING.md`); the app's own first screen was not run for this brief | `FillerActivity`, the only screen and the launcher entry: one line of purpose, **Choose folder**, the measured free space, the part kept free, **Start filling** |
| Description | opens "Fast Media Sorter is a file organizer for Android", then eight pillars of a device shell; 3917 characters; never mentions the Filler | opens "Filler fills the free space of a storage device with temporary files and then deletes them again"; five short blocks (where, fill and follow, clean up, any device and the watch, privacy) |
| Screenshots | 8 phone slots (`launcher`, `image-viewer`, `video-player`, `streams`, `apps`, `stock-apps`, `monitor`, `browse`), 4 Wear OS frames, a ten-inch set | none uploaded: no device run of the finished app exists yet (S0006, S0020) |
| Icon and feature graphic | FastMediaSorter's own artwork | the Filler block of FastMediaSorter, inherited in S0050 - the upstream `ic_storage` geometry on this product's launcher canvas (`docs/play/icon-512.png`, `feature-graphic-1024x500.png`); SHA-256 of both files differs from the FastMediaSorter files of the same role |
| Permissions it tells the user about | all-files access and, optionally, location | none; no internet access |
| The one reason to install | one app that replaces the launcher, the player and the file manager | one small app that fills a storage's free space and removes only what it wrote |

## 2. What was measured

- Shared wording, English: the Filler's three store fields against the FastMediaSorter title, short and full description,
  by word n-grams: **0 shared six-word sequences, 1 shared four-word sequence** ("nothing leaves your device"). Russian:
  0 and 0. Ukrainian: 0 six-word and 1 four-word ("ні облікового запису ні"). Both are privacy phrases, not sentences of
  the description.
- The word "filler" occurs in no FastMediaSorter listing source (`play/listing`, `meta/listing`, `fastlane/metadata`):
  grep of 2026-11-13, 0 hits. FastMediaSorter's entry does not advertise the sub-program, so the two entries do not
  describe the same feature to the same reader.
- The icon and the feature graphic are different files (SHA-256 compared).
- Not measured: how the live store pages render, and whether any FastMediaSorter screenshot happens to show the Filler
  (the images were not opened; the caption slots above name none).

## 3. The policy text, and the date it was read

Read on **2026-11-13** from the Play Console Help page "Spam" (`support.google.com/googleplay/android-developer`, article
9899034), section **Repetitive Content**. The page shows no revision date, only a copyright year in its footer. Quoted:

- "We don't allow apps that merely provide the same experience as other apps already on Google Play."
- "Creating multiple apps with highly similar functionality, content, and user experience."
- "developers should consider creating a single app that aggregates all the content." (said of apps that are each small in
  content volume)

Also read the same day, "Best Practices for White Label Developers" (article 15884185, no revision date), which lists as
what to avoid: "Using the exact same descriptions for multiple apps", "Using the same store listing screenshots for
multiple apps" and "Repurposing the same featured graphics for multiple apps".

**Not read, therefore not described:** the enforcement text of the Spam policy (the fetched part of the page held none),
the policy "Minimum Functionality", and how Google treats an app that is one function of a larger app of the same
account. The portfolio's note that the repetitive-content policy works at account level (FastMediaSorter S4070 section 7,
recorded in S0016 section 3.4) is the portfolio's own note, not policy text read today, and is not repeated here as a
quotation. A reviewer's reading of this pair is not predicted by this brief.

## 4. What the brief commits the listing to

1. **No shared description, screenshot or graphic.** The white-label page names exactly these three as the things to
   avoid, and section 2 shows the texts and graphics are different today. Any later edit keeps it so: the check is the
   n-gram comparison of section 2 (zero shared six-word sequences) and a hash comparison of the graphics.
2. **Every screenshot shows the Filler.** The first set of screenshots, taken from the finished app on a real device
   (S0006 D1 to D12, S0020), shows only the Filler screen and its states: choosing the folder, the measured space and the
   reserve, the confirmation, the run, the cleanup retry, and the watch. No FastMediaSorter screen, no launcher or media
   frame, and no caption that reuses a FastMediaSorter caption. Captions are about the single purpose.
3. **The description makes only the claims the screen keeps.** The run paragraph names how much is written, the
   percentage and the time left, which is what the running screen shows; the write speed it once named was removed from
   the texts by S0024 (2026-11-13), and the screen shows no speed figure. This brief changes no listing text.
4. **The permission story stays the product's reason.** "Asks for no permission and has no internet access" is a claim
   that the FastMediaSorter entry cannot make; it is true here by the manifest (`docs/play/PLAY_DATA_SAFETY.md`) and is
   written only while it stays true (canon invariant 14).
5. **The 2018 notice is read before the first review** (S0022 item 2): the account holds a removed app of the same name
   (`CLAUDE.md` section 3), and its notice is in the owner's mailbox; it was not read from here, so this brief says nothing
   about what it cites.
