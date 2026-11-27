# Documentation overlap map - FastMediaSorter's Filler and Filler for Android

Which FastMediaSorter documents describe the Filler, which surface of this product each one overlaps, and the rule that
keeps the two sets of texts in step. Written under S0016 on 2026-11-13 against the FastMediaSorter checkout at HEAD
`1a3ddca74` (read-only from here; the checkout is never edited). The map is an explicit statement of overlap, not a copy
of anything: `docs/PROGRESS_PORT_INTAKE.md` records the overlap as "adapted" (row of 2026-11-13, carrier S0016), and
`docs/SPECIFICATION_SYNC_MODEL.md` sections 2 and 4 carry the triggers and dispositions this page relies on and does not change.

## 1. The principle

- **The behaviour is the source; the text is authored here.** Every user-facing text of this product (the listing, the
  README, the in-app strings, a future help page and landing, the watch pages) is written from the behaviour this product
  ships, as a shipped present-tense fact (canon invariant 17). A FastMediaSorter document is read for facts at the moment
  a port ticket re-inventories the source (`CLAUDE.md` section 2.2), never pasted and never used as the master of a
  sentence here. The reason is concrete: FastMediaSorter's Filler text lives in a programs menu and an Operations
  settings switch that this product does not have (`docs/PROGRESS_PORT_INTAKE.md`, rows of S4542 and the entry surfaces).
- **One listing, one voice per product.** The store entry of this product shares no sentence with FastMediaSorter's
  (`docs/RESEARCH_LISTING_BRIEF.md` section 4); a text that is "kept in step" is kept in step in its facts, not in its
  words.

## 2. The map

"Source" is a FastMediaSorter file; paths are relative to its checkout. "Here" is the surface of this product that states
the same fact. A row with no source is a surface that FastMediaSorter has no counterpart for.

| # | Source (FastMediaSorter) | What it holds | Here | Relation |
| --- | --- | --- | --- | --- |
| 1 | `docs/FEATURES.md` line 176, `docs/FEATURES-ru.md` and `docs/FEATURES-uk.md` line 176 | the feature entry: where it fills, the reserve, deletion, retry after a stop or a removed card, run by hand or on a schedule, the on/off switch | `README.md` first paragraph; `docs/play/PLAY_LISTING.md` and its `-ru`, `-uk` translations (the full description) | facts carried, sentences not; the schedule and the switch are out of the first release (S0012 rows 5 and 6; scheduled fill returns with S0025) |
| 2 | `docs/HOW_TO.md` line 1475; the same entry exists in `docs/HOW_TO-ru.md` (line 1463) and `docs/HOW_TO-uk.md` (line 1471) and no line with its reserve figures in the other ten translations (a figure grep of 2026-11-13) | how to use it: the 1 GB default reserve, the slider down to 10 MB for the next run, the start confirmation naming it, **Delete remaining files** | the Filler screen strings `phone/src/main/res/values*/strings_filler.xml` (13 locales) and the help entry of S0028 | the strings are ported code and tracked by the ledger; the help entry is authored here from the same facts, and the numbers are the contract `FILLER-RESERVE` |
| 3 | `docs/WHATS_NEW.md`, `-ru`, `-uk` lines 24 and 25 | the release note that announces the Filler and the scheduled fill | the "What's new" of this product's first release (S0023 gap G7, `ledgerShape` is `none` today) | no source: this product's first note announces the app itself, written at release time |
| 4 | `docs/SETTINGS_REFERENCE.md` line 306 (+ `-ru`) | the Operations switch that adds the Filler to the programs list | nothing | out, a deliberate difference (S4542, S0012 row 6): a switch that hides the Filler has no meaning in an app that is only the Filler |
| 5 | `docs/ICON_LEGEND.md` (+ `-ru`, `-uk`) and `docs/icons/icon-inventory.json`, id `storage_filler` | the in-app glyph and its legend line | the launcher glyph `phone/src/main/res/drawable/ic_launcher_foreground.xml` (the inherited Filler block, S0050) | the glyph is inherited (S0050): its geometry is the upstream `ic_storage` path, scaled for this product's launcher canvas and rendered by `tools/store/render-store-assets.ps1`; the legend page itself stays out, a deliberate difference |
| 6 | `docs/content/recipes/storage-scheduled-operations.md` and `documentation/storage/scheduled-operations.html` | the scheduled-fill recipe | the scheduled-fill help text, written when S0025 ports the behaviour | follow-on (S0012 row 5, S0025) |
| 7 | `docs/ARCHITECTURE.md` line 478 | the availability input of the Filler (S4542) | nothing | out; internal and not a user text |
| 8 | `docs/ALL_FEATURES.jsonl` ids `general.storage-filler` (S4567) and `file-operations.scheduled-fill-free-space` (S4522), `docs/coverage-manifest.jsonl` | the feature identifiers of the family | the `FUNCTION-PARITY` register column, when the register exists (S0014) | the ids are the shared key; no copy of the rows is kept here |
| 9 | FastMediaSorter `README.md` line 88 | one clause in a list of what the release added | `README.md` | no relation to carry; the clause is a FastMediaSorter release summary |
| 10 | `play/listing/*/full_description.txt`, `meta/listing`, `fastlane/metadata` | the FastMediaSorter store texts | `docs/play/PLAY_LISTING*.md` | **no overlap**: none of them contains the word "filler" (grep of 2026-11-13); the entry here is independent by construction |
| 11 | `documentation/help/` (the in-app help pages) | the FastMediaSorter help | the help entry of S0028 | **no overlap**: FastMediaSorter has no Filler help page (no "filler" in `documentation/help/`, grep of 2026-11-13) |
| 12 | none | - | `site/privacy.html`, `-ru`, `-uk` and `docs/play/PLAY_DATA_SAFETY.md` | derived from this product's manifest and behaviour (the five permissions of the scheduled fill, S0025, and no internet access), not from a FastMediaSorter Filler text; FastMediaSorter's privacy policy was not read for this map |
| 13 | none: FastMediaSorter has no Filler on the watch (no "filler" in its `wear/` tree beyond one unrelated comment; grep of 2026-11-13) | - | the watch pages and strings of S0018 to S0020 | a new surface designed from the phone Filler of this product; its source is rows 1 and 2 through the phone texts |
| 14 | none | - | the landing `site/index.html`, `-ru`, `-uk` (S0031) | built from this product's listing texts, README and privacy pages (rows 10 and 12 give the sources), not from a FastMediaSorter page; authored under rule 1 of section 3, and `tools/site/check-site.ps1` holds the three languages as one set with a translation pin |

## 3. The rule that keeps the texts in step

1. **A port or a fix names its texts.** A ticket that ports a change in the FastMediaSorter Filler, or fixes a defect in
   behaviour both apps share, lists in its Files Touched every surface of the "Here" column that states the changed fact,
   and edits them in one edit, every authored locale of each (the listing and the privacy pages in en, ru and uk; the
   screen strings in all 13). The pass that works the Draft ticket opened by `tools/port-ledger/pass-start.ps1` does this
   (`docs/SPECIFICATION_SYNC_MODEL.md` section 4, disposition "port").
2. **The re-inventory reads the source documents.** The re-inventory of `CLAUDE.md` section 2.2 reads the "Source" files
   of rows 1, 2, 6 and 8 beside the code, so a wording fact (a number, a label, a limit) that moved in FastMediaSorter's
   text is found when the behaviour behind it is compared.
3. **A fact has one home.** The default reserve and the floor are the contract `FILLER-RESERVE` (rules 1 and 2) and the
   constants `FILLER_RESERVE_BYTES` and `FILLER_MIN_RESERVE_BYTES` in `filler-core`; the stops of the slider are
   `FillerUiState.RESERVE_CHOICES_BYTES`. The listing, the README and the help quote them and are checked against those,
   never against a FastMediaSorter sentence. A number that appears in a text and in no contract or constant is not
   written.
4. **The watch follows the phone.** A change in a phone text that states a Filler fact (row 13) opens a line for the
   watch pages in the same ticket (`docs/SPECIFICATION_SYNC_MODEL.md` section 6, per-surface files).
5. **A difference is written where it lives.** A text that deliberately says less or something else than the
   FastMediaSorter one (rows 4, 5, 7) is a deliberate difference recorded in the intake log
   (`docs/PROGRESS_PORT_INTAKE.md`), not silently dropped.

## 4. The blind spot, stated

The drift check watches code, resources and tests (`docs/port-scope.json`); it does not watch FastMediaSorter's Markdown
or HTML. A change made only to a FastMediaSorter Filler document, with no behaviour behind it (a reworded sentence, a new
translation), is not seen by the check and is not a change to carry: it reaches this product only if a person reads it at
the re-inventory (rule 2), and nothing is lost when it does not. A change to the behaviour always moves a watched file and
is therefore seen. Putting FastMediaSorter's documents into the watched scope would turn every wording edit upstream into
a Draft ticket here; that is not proposed.

## 5. Contracts

This page is internal documentation of the repository (`DOC-INTERNAL-QUALITY`, held by `tools/docs/check-docs.ps1` since S0026, the registry is `docs/DOCUMENT_REGISTRY.jsonl`); it is
not user documentation or a help centre, so the declared-not-applicable row of `DOC-EXTERNAL-QUALITY` stays closed. It was
re-judged at the landing (S0031) and reopens with the first published help page or manual (`docs/contracts/README.md`).
