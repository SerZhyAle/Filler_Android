# docs/ - index

| Path | What it is |
| --- | --- |
| `PLAN_BOOTSTRAP_HANDOFF.md` | the record written when FastMediaSorter S4523 requested this project; a starting record, work is driven from the ticket store |
| `SPECIFICATION_SYNC_MODEL.md` | how a change in FastMediaSorter's Filler reaches this product, who decides, what happens to a defect found here, how a fix lands in both apps |
| `PROGRESS_PORT_INTAKE.md` | the log of every change seen in the FastMediaSorter Filler, with its disposition and carrier |
| `SPECIFICATION_DOC_OVERLAP_MAP.md` | which FastMediaSorter Filler documents overlap which surface of this product (phone and watch), and the rule that keeps the texts in step (S0016) |
| `RESEARCH_LISTING_BRIEF.md` | the Filler's Play entry against FastMediaSorter's: start screen, description, screenshots, the one reason to install each, the policy text read and its date (S0016) |
| `SPECIFICATION_POSITIONING.md` | the positioning source: the five pillars of what Filler is for, in their order, and the seven surfaces written from it (the three landing pages, the README opening, the three listing sources); `tools/site/check-positioning.ps1` holds the order (`SITE-REPRESENTATION` rules 1 and 2, S0040) |
| `SPECIFICATION_FAMILY_MAP_ROW.md` | the proposed row for this product in the family map (`SITE-FAMILY-MAP`), prepared and not filed until the landing answers (S0016) |
| `PLAN_FMS_HANDOFF_NOTE.md` | what is owed on the FastMediaSorter side: a link to the Filler, the assumption that the Filler stays in both products, the source's side of the sync; text only (S0016) |
| `SPECIFICATION_UI_SIZE_PROFILE.md` | the size-profile record of the phone screen (input profile, baseline and range, button tokens, smallest targets, glyph bounds, measured pairs) and its policy for which commands carry an `ICON-SET` glyph (S0027) |
| `port-ledger.jsonl` | the port ledger: every ported file with the SHA-256 of the source version it holds (tools: `tools/port-ledger/`) |
| `port-scope.json` | the part of the FastMediaSorter tree the drift check watches |
| `site-held-addresses.jsonl` | the addresses of the site that outside surfaces hold (the README, the Play Console fields, the repository homepage, the sibling sites) and the anchors of each page, resolved against the page set by `tools/site/check-site.ps1` (`SITE-STRUCTURE` rule 8, S0039) |
| `AGENT_HOOKS.md` | the inventory of the agent hooks this repository registers (the `SessionStart` hook of the drift check) |
| `DOCUMENT_REGISTRY.jsonl` | the document registry of the maintained corpus (`AGENTS.md`, `CLAUDE.md`, `README.md`, `docs/`, `PLAN/` and the Markdown under `tools/`): one record per document group, with its topic, product area, update triggers and, for a generated file, its generator and check (S0026; checked by `tools/docs/check-docs.ps1`) |
| `INSTALL_TRUST.md` and its `-<code>` siblings | the install guide for the signed APKs in every product language (en, ru and uk hand-written, the rest rendered by `tools/locale/`) |
| `contracts/` | pointers to the shared contracts this product is bound by, indexed with version, role and state |
| `play/` | the Google Play listing texts in every product language (en, ru and uk hand-written, the rest rendered by `tools/locale/`), the App content answers, the release and review record, and the listing graphics |
| `releases/` | the release ledger (`channels.json`, `builds.json`, `history.jsonl` and rendered `RELEASES.md`, S0054; writer: `tools/harness.ps1 releases/release-ledger`) |
| `github/` | the repository social preview |

## Former names

Three documents were renamed on 2026-11-13 (S0026) to carry a type prefix (`REPO-LAYOUT` rule 3). Tickets and archived
records that were written before the rename still cite the old names; they are kept as written, and this table is the
way from an old name to its document.

| Former name | Name now |
| --- | --- |
| `docs/BOOTSTRAP_HANDOFF.md` | `docs/PLAN_BOOTSTRAP_HANDOFF.md` |
| `docs/SYNC_MODEL.md` | `docs/SPECIFICATION_SYNC_MODEL.md` |
| `docs/PORT_INTAKE.md` | `docs/PROGRESS_PORT_INTAKE.md` |
