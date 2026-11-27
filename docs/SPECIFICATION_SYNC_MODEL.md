# Sync model - FastMediaSorter's Filler and Filler for Android

One page. Source of the rules: owner statement of 2026-11-13 (new and corrected functionality is updated in the apps
in parallel), FastMediaSorter S4053 section 5.1.7 and S4065 (the pull model), and the catalog contract
`PORT-LEDGER` 0.1 (rules 3, 7, 8, 9, 10 and 11). The tools are in `tools/port-ledger/`, the record is
`docs/port-ledger.jsonl`, the log of seen changes is `docs/PROGRESS_PORT_INTAKE.md`.

## 1. Direction and its limit

- **FastMediaSorter to Filler, pull.** This product compares itself with the FastMediaSorter checkout; the checkout
  is read-only from here and is never edited.
- FastMediaSorter owes this product nothing under S4065. Its side of the sync is `PORT-LEDGER` rule 11 (its release
  preflight lists this product's uncarried files, informationally); that step belongs to FastMediaSorter's own
  tickets and is not made from here.
- So a change made in FastMediaSorter reaches this repository as a queued Draft ticket within one `pq` pass of being
  detected, not as shipped code at the same moment. Shipping is a release of this product.

## 2. Triggers

| Trigger | What runs | What happens |
| --- | --- | --- |
| Start of every session in this repository, including every `pq` pass | `.claude/settings.json` `SessionStart` hook, `tools/port-ledger/pass-start.ps1` | the drift check; an undecided drift opens one Draft ticket through the `spec-draft` flow, naming each moved FastMediaSorter file and its hash |
| Release preflight | `tools/port-ledger/check-drift.ps1` | exit 1 on any undecided drift refuses the release (`PORT-LEDGER` rule 9) |
| Every port ticket | the re-inventory of `CLAUDE.md` section 2.2 | the ticket reads the source first, then the check |
| On demand | `check-drift.ps1` | before any claim of parity |

A file is filed once: the ticket carries the token `port-drift: <source> <status> <hash8>`, and a token named in any
ticket is not filed again. The release preflight stays the backstop whether or not a ticket exists.

## 3. What is watched

- **The ledger** lists every ported file with the hash of the source version it holds.
- **The scope file** (`docs/port-scope.json`) lists the part of the source this product watches: the upstream Filler
  files, screens, layouts, strings and tests, and the scheduled fill. A file in scope with no ledger row and no
  exclusion (with a reason) is `NEW SOURCE`, so a file FastMediaSorter adds later is not invisible.
- **Blind spot, stated:** behaviour that changes in a file outside the scope (for example the programs menu or the
  settings switch) is seen only by a person. The intake log and the Filler-adjacent triage of S0012 are where it is
  written down.

## 4. Who decides

Every drifted file gets one disposition, written once, pinned to the source hash it was decided at:

| Disposition | Record | Decided by |
| --- | --- | --- |
| **port** - carry the change | the change is made here with its tests, then `record-port.ps1 -Refresh` (writes `carriedOn`) | the pass that works the Draft ticket |
| **not applicable** - the change concerns FastMediaSorter only | `decide-drift.ps1 -Note` naming the reason and the ticket | the pass that works the Draft ticket; the owner may overrule |
| **deliberate difference** - this product keeps its own behaviour | `decide-drift.ps1 -Note`, and the difference written at the head of the ported file (`CLAUDE.md` section 2.3) | the owner when it changes behaviour a user sees or the scope of the product; otherwise the pass, recorded as an unattended assumption |

A decision stops covering a file the moment the source changes again. Parity is the standing law (`CLAUDE.md` section
2): the default for a change in the Filler is **port**.

## 5. A defect found here

A defect in behaviour both apps share is not fixed by editing FastMediaSorter. It is reported to the FastMediaSorter
owner as a hand-off note (`PORT-LEDGER` rule 10; a defect in a catalog contract is a proposal beside that contract).
The note is written as text in the ticket that found it, with the evidence and the fix made here; the FastMediaSorter
owner takes it into FastMediaSorter's queue. The fix here is ported back by the same ledger when FastMediaSorter
carries it, so the row ends in step.

## 6. How a fix lands in both apps of this product

The pure Filler logic - the engine, the session journal and the progress estimator - lives in one module,
`filler-core`, consumed by `phone` and, once S0018 creates it, by `wear` (S0003, S0013). It is fixed once and reaches
both apps; nothing is copied between them. What is per surface (the storage adapter and the screen) is fixed per
surface, and a fix to a per-surface file opens a line for the other surface in the same ticket.

## 7. Changing this page

A new trigger, a new disposition or a change of direction is a decision of the owner and is recorded in a ticket
before this page changes.
