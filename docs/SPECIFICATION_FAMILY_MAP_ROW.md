# Proposal - a row for Filler in the family map (`SITE-FAMILY-MAP`)

Prepared under S0016 criterion 3 on 2026-11-13, for the owner of the contract (the sza.od.ua portfolio hub). **Not filed.**
The catalog's rule is "another product's contract is amended by proposal, not by edit"; this page is the text of that
proposal, to be placed beside the contract in the catalog when the condition in section 4 is met. Nothing here edits the
catalog, and the contract is cited by id and section only.

## 1. Finding

`SITE-FAMILY-MAP` 1.12, section 2, lists nine rows. It has no row for Filler for Android, and none for the other Android
products extracted from FastMediaSorter. The owner's stated end state (2026-11-13) is that the standalone Filler belongs to
one visible family with FastMediaSorter and the other tools, which in this contract's terms means a row (rule 1: a product
in the table is in every other product's landing footer) and, once it answers, a hub card with its channels (rule 2,
1.11).

## 2. The proposed row

| Tool | Type | URL | Help index |
| --- | --- | --- | --- |
| Filler | Android storage filler | https://serzhyale.github.io/Filler_Android/ | - |

- **Tool.** The product's own display name (1.9): `app_name` and the launcher label read **Filler**; the store title is
  "Filler: Fill Storage Space". The brand is the in-app name, as for the existing Android row (1.3: the cell is the name a
  user meets in the product). Alternative for the hub to choose: the longer store title, if it prefers the Play title.
- **Type.** One short label, parallel to "Android media sorter" and "Windows storage CLI"; a page in another language may
  render it in its own words (1.12). This product's pages are in en, ru and uk.
- **URL.** The Pages site of the public repository `SerZhyAle/Filler_Android`, the same host pattern as the other rows.
- **Help index.** `-`: the product has no help index (CONTEXT-HELP gap, S0028).
- **Contact.** Rule 3 holds on this product's pages: the three privacy pages carry `sza@ukr.net` and the hub link; no other
  primary address appears.

## 3. What accepting it costs (the contract's own wording, section 3 rule 1)

Adding a row is work for every landing: each consumer of the map adds the row to its footer grid (the consumers named by
the contract: the hub, FastMediaSorter_mob_v2, FastMediaSorter_Lite, CyrFlip, doc-html-translate, FileDO,
universal-agent-kit, OneClickRunner, StreamsPlayer). Section 4 of the contract calls adding a tool additive (MINOR): a page
that has not caught up shows a shorter grid and misstates nothing. Filing the row also makes this product's landing owe the
other nine rows in its own footer grid (rule 1, "all the others"), which is a part of the landing work, not of this
proposal. Conformance (section 5) adds one URL to the `curl` check.

Not asked: a change to rule 4 (contextual cross-links). Whether a landing or help page of FastMediaSorter should name the
Filler in body copy is the FastMediaSorter owner's call (`docs/PLAN_FMS_HANDOFF_NOTE.md`, item 1); this proposal needs no
amendment either way.

## 4. When it is filed

**Condition:** the landing at the URL answers 200 (rule 5: a URL enters the table only once it answers). The landing is
built (S0031, 2026-11-14: `site/index.html`, `-ru`, `-uk`, its footer grid already carries the nine rows of the map) but
not pushed, so the served root still answers 404, the repository has no homepage and the Play listing has no website
(`CLAUDE.md` section 3); the owner's push deploys it (S0022 item 6). The condition S0016 set - the store name chosen - is met
(S0007, 2026-11-13: "Filler: Fill Storage Space", the brand "Filler").

**Filing, when the condition holds:** one file `PROPOSAL-<date>-filler-android-family-map-row.md` beside the contract, from
Filler Android, carrying section 2 and the `curl` evidence of the day, status `proposed`. The follow-on tickets (the hub
row and card, the footer grids of the consumers) are filed by S0022 item 11 once the landing and the Play listing both
answer 200.

## 5. Assumed (unattended, 2026-11-13)

- **Filing waits for the landing.** Alternative: file the proposal now with the condition stated. Weighed: the contract's
  rule 5 forbids a row whose URL does not answer, so a proposal filed now could not be applied and would sit open in the
  catalog until the landing exists; a prepared text loses nothing by waiting. The owner may overrule, and the filing is
  a one-file step.
- **The Tool cell is "Filler".** Alternative: "Filler: Fill Storage Space". The hub decides; the proposal states both.
