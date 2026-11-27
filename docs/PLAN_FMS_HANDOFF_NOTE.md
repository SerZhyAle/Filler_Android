# Hand-off note for the FastMediaSorter owner - what is owed on that side

Written under S0016 criterion 4 on 2026-11-13, from Filler for Android to the owner of FastMediaSorter Android. **Text
only.** No FastMediaSorter file, ticket or document is changed or read as a ticket from here; the checkout is read-only
(`CLAUDE.md` section 1). The owner of FastMediaSorter takes the items into FastMediaSorter's own queue, or does not; each
item says what holds if it is not taken.

## 1. A link to the Filler, once it is public

**Ask.** When the Filler's landing and its Play listing both answer 200, FastMediaSorter's documents and site link to it:
the Filler entries of `docs/FEATURES.md`, `docs/HOW_TO.md` and their translations, and the site, in the form
FastMediaSorter S4279 used for StreamsPlayer (the form is named by this ticket's records; that ticket was not read from
here). The footer-grid row follows from the family map (`docs/SPECIFICATION_FAMILY_MAP_ROW.md`, rule 1 of
`SITE-FAMILY-MAP`), not from this note.

**Not yet possible.** Neither address answers today (the landing of S0031 is built and not pushed, so the Pages root is
404; nothing is uploaded to Play), so the note
does not give a URL to link. The trigger is `S0022` item 11 of this repository, which files the hub and footer-grid
tickets at that moment; the FastMediaSorter owner is told then.

**If not taken.** FastMediaSorter's pages do not mention the standalone app; both texts stay correct, and nothing else
depends on the link.

## 2. The assumption that the Filler stays in both products

**Assumed (S0016 section 3.2, unattended, 2026-11-13):** the Filler stays inside FastMediaSorter after the standalone
release. The owner states that the apps develop together and that new and corrected functionality reaches them in
parallel; that presupposes both exist. It is the choice already made for streams (FastMediaSorter S4065, 2026-10-16),
with double maintenance and the pull sync of S0011. Alternative: a staged hand-over, FastMediaSorter pointing its users to
the standalone app. The owner of FastMediaSorter may overrule.

**What the assumption means for FastMediaSorter.** Nothing is owed under S4065's pull model: this product compares itself
with the FastMediaSorter checkout at the start of every session and every release preflight (`docs/SPECIFICATION_SYNC_MODEL.md`
sections 1 and 2). A Filler change made in FastMediaSorter reaches this product as a Draft ticket here. The one thing
FastMediaSorter is asked to carry is item 3.

**If the assumption is overruled** (a hand-over): the Filler leaves FastMediaSorter's programs list, the drift check here
compares against a frozen release (release 48, the baseline of S0010), and `docs/SPECIFICATION_SYNC_MODEL.md` changes by a recorded
owner decision (its section 7).

## 3. The source's side of the sync (`PORT-LEDGER`, the catalog proposal of 2026-11-13)

The catalog proposal `_meta/PROPOSAL-2026-11-13-new-contract-source-port-ledger.md` asked the owner to decide rule 8, the
source's side of the sync, among three options (the source owes nothing; the source opens a hand-off ticket; the source's
release preflight lists the derived products' uncarried files, informationally). **That decision is recorded in the
proposal itself** ("Decision (2026-11-13)"): option R was accepted, as rule 11 of `PORT-LEDGER` 0.1, on the portfolio
owner's order of the same day, replacing for this one report the pull-only model of 2026-10-16 (S4065). The contract is a
draft and binds nobody until each product adds its consumer row.

**Ask.** FastMediaSorter's release preflight runs the drift check of every registered derived product and lists the
uncarried files in its verdict, informationally and never blocking the FastMediaSorter release. It needs only the ledgers
of the derived products; this product's is `docs/port-ledger.jsonl` (30 rows) with the scope in `docs/port-scope.json`, and
its check is `tools/port-ledger/check-drift.ps1`. That is a step of FastMediaSorter's own tickets.

**If not taken.** The sync stays pull-only and still works: this product detects drift itself. FastMediaSorter loses the
standing view of what each derived product has not yet carried; nothing breaks.

## 4. Findings from this product's reading, for information

- FastMediaSorter's Play listing, its listing sources and its in-app help pages do not mention the Filler at all (grep
  of 2026-11-13: 0 hits in `play/listing`, `meta/listing`, `fastlane/metadata`, `documentation/help`). The sub-program is
  documented in the feature list, the how-to, the settings reference, the icon legend, the release notes and the
  scheduled-operations recipe only (`docs/SPECIFICATION_DOC_OVERLAP_MAP.md` section 2).
- The how-to entry for the Filler exists in English, Russian and Ukrainian; the other ten translations of
  `docs/HOW_TO-*.md` hold no line with its reserve figures (1 GB, 10 MB; grep of 2026-11-13, a figure search, not a
  reading of each file). Whether that is intended is FastMediaSorter's call; it affects no text here.
- Defects found here in behaviour both apps share: none open. When one is found it comes as a note in the ticket that found
  it, with the evidence and the fix made here (`docs/SPECIFICATION_SYNC_MODEL.md` section 5). One text-against-screen finding of this
  product (the write speed named in this product's listing, S0024) concerns this product's own text and is not a hand-off.
