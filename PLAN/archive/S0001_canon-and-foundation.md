# S0001 - Complete canon adoption and project foundation

**Ticket:** S0001
**Status:** Verified
**Priority:** 80
**Tier:** 3 - Moderate
**Complexity:** medium - assessed at the spec pass: bounded adoption work across the stamp, two agent files, the ignore list, the day-0 scaffold and one record in the canon repository; no code, and the only decision is one recorded exemption. Read against the plan: the level stands.

## Goal

Complete a truthful, independently maintainable project foundation for Filler. `docs/BOOTSTRAP_HANDOFF.md` and FastMediaSorter S4523 are the starting record; S4521 is the upstream feature.

## Scope and acceptance

- Reconcile the bootstrap stamp and agent contracts against the current SZA canon for an Android overlay B product. The initial stamp supports scheduler discovery, not a claim that every canon requirement has been satisfied. Complete the adoption records and compliance checks.
- Validate the shared harness, catalog and release queue in this project; keep PLAN tracked and secrets outside the project. Keep Filler's independent root and release boundary.
- Record actual checks and unresolved owner decisions. Do not select published identifiers, signing, license, remote or distribution channel by assumption.

### 3.3 Owner inputs (Approval gate)

- **Related tickets:** FastMediaSorter S4523; FastMediaSorter S4521 is upstream. Filler S0002 follows.
- **Owner decisions this ticket records and does not take:** application id, signing key, license, public remote, distribution channel, site and privacy page, store name - n/a here, carried to S0007 (see the open questions).
- **Contract boundary:** n/a - the product holds no shared contract today; no catalog amendment is owed.

## Spec pass (2026-11-10)

- **Rung:** complex pipeline. Forced upward by the primitive test: more than three files change and new files are created (the stamp, both agent files and the ignore list, the scaffold's launchers and plan files, one record in the canon repository).
- **Baseline measured before any edit:** the compliance gate exited 1 with 3 errors and 1 warning (`SZA-LAY01` no `LICENSE`, `SZA-RULES02` no canon pointer in `AGENTS.md` and in `CLAUDE.md`, `SZA-SEC02` missing leak globs); `spec_catalog/validate` exited 0 with 10 OK; the stamp digest equals the installed canon's, so nothing is re-synced and no version is written by hand.
- **Settled without asking** (the records answer them): the unattended children's permission mode is the registry's recorded choice, `bypassPermissions` (`pq list -Json`), so the scaffold default is right; the product holds no shared contract (a case-insensitive search of the catalog finds only the English word "filler"); the ticket id scheme is the harness default `Sxxxx`; `PLAN/` stays tracked because the scope says so and there is no remote.
- **License:** the only compliance error that needs an owner decision. The scope forbids choosing it, so it is a dated exemption in the stamp, not a file.

## Done criteria

Each is a command to run or a file to read.

1. The canon compliance gate, run from the installed plugin root, exits 0 with 0 errors.
2. `tools/harness.ps1 spec_catalog/validate` exits 0 with 0 FAIL, and `spec_catalog/release-queue -Validate` exits 0.
3. `r0.ps1 -DryRun` exits 0 and lists S0001 as the one open ticket.
4. `CLAUDE.md` names the canon, the overlay, the model `reference` and the contrib record; `AGENTS.md` is the delegating stub; neither carries a restated universal rule (the gate's `SZA-RULES03` is silent).
5. `.gitignore` ignores `temp/`, `*.jks`, `*.snk`, `*token*`, `*secret*` and does not ignore `PLAN/` (`git check-ignore -v`).
6. No decision is taken by assumption: no `LICENSE` file, no `applicationId`, no signing file, no remote in the tree, and the open list in `CLAUDE.md` section 3 names each one with the ticket that needs it.
7. The contrib record exists in the canon repository and carries a dated adoption section.

## Plan

Coverage: acceptance bullet 1 -> phases A, B, C, D; bullet 2 -> phase E; bullet 3 -> phase A (open list), E (checks). No phase consumes what a later one produces.

- **A. Agent contracts and ignore list** - files: `CLAUDE.md`, `AGENTS.md`, `.gitignore`. Check: criteria 4 and 5.
- **B. Stamp** - file: `.sza-canon.json` (`schemaVersion`, `reconciledOn`, `contribRecord`, the LICENSE exemption with `until`). Check: the gate reads it with no `SZA-CANON` error.
- **C. Day 0 of the task flow** - the harness scaffold (plan files, stores, template, launchers) and the spec-command registration. Check: the printed `created` lines, criterion 3.
- **D. Contrib record** - `rules/contrib/filler_mob.md` in the canon repository, the one write the canon allows from here. Check: criterion 7.
- **E. Evidence** - criteria 1, 2, 3, 6 run fresh, exit codes read.

## Open questions

1. **Application id and its freeze.** Status: Open. The owner has not chosen it; S0002 builds under an explicit provisional id that is not an anchor. Carrier: S0007
2. **Signing key, its location outside this tree, Play signing mode.** Status: Open. Not chosen; nothing signed or created. Carrier: S0007
3. **License.** Status: Open. `LICENSE` is absent on purpose; the `SZA-LAY01` exemption lapses on 2027-02-10 and S0007 adds the file or renews the entry. Carrier: S0007
4. **Public remote, distribution channel or channels, site and privacy page, store name and branding.** Status: Open. None chosen. Carrier: S0007
5. **Form of the parity inventory against S4521** (a committed port ledger with a SHA-256 drift check as in StreamsPlayer_mob and Tourist_mob, or another). Status: Open. Depends on the upstream's completed shape. Carrier: S0003
6. **Package versioning contract declaration** (Android profile). Status: Open. It binds a build that does not exist yet; the registry row and `docs/contracts/` come with the first declared contract. Carrier: S0002
7. **Input parity, in-app help and the unified UI contract declarations.** Status: Open. They bind screens that do not exist yet. Carrier: S0005
8. **Does the product hold a shared contract today?** Status: Resolved - no. A case-insensitive search of the catalog for the product name finds only the English word "filler" in two unrelated documents, and the registry has no row for it.
9. **Permission mode of the unattended children.** Status: Resolved - `bypassPermissions`, the registry's recorded choice (`pq list -Json`), equal to the scaffold default.

## Last Audit

**Date:** 26-11-10 21:27 | **Mode:** static | **Outcome:** Verified
**Counts:** PASS 12 | WARN 0 | FAIL 0 | MANUAL 0 | UNCHECKABLE 0 | EXEMPT 2 | RELEASE 0

Evidence, each run fresh in this pass (expected | actual):

1. Compliance gate from the installed plugin: exit 0 | exit 0, 0 error(s), 1 warning(s); before the work: exit 1, 3 error(s), 1 warning(s). PASS.
2. `spec_catalog/validate`: exit 0, 0 FAIL | exit 0, Summary 10 OK, 0 WARN, 0 FAIL. PASS.
3. `spec_catalog/release-queue -Validate`: exit 0 | exit 0, "OK - 7 ticket(s), no drift". PASS.
4. `r0.ps1 -DryRun`: exit 0, S0001 the one open ticket | exit 0, "1 open ticket(s)". PASS.
5. `CLAUDE.md` carries canon, overlay B, model reference and the contrib record; `AGENTS.md` is the stub; `SZA-RULES02` and `SZA-RULES03` silent | confirmed by the gate run of item 1 and by reading both files. PASS.
6. `git check-ignore -v`: `temp/`, `*.jks`, `*.snk`, `*token*`, `*secret*` ignored, `PLAN/` not | all five ignored by their `.gitignore` lines, the ticket file not ignored. PASS.
7. No decision by assumption: no `LICENSE`, no signing file, no remote, no `applicationId` outside prose | file search over the tree found none; `git remote -v` printed nothing. PASS.
8. Contrib record in the canon repository with a dated adoption section | present, section heading at line 54; the gate run from the canon checkout (same core digest `9abe1d23..`): exit 0, 0 error(s), 0 warning(s). PASS.
9. Probe invariant: no ticket-id probe in source | `phone/src` holds no file. PASS.
10. Scope purity: edits inside the scope | the stamp, both agent files, the ignore list, the scaffold output, this spec, and the one allowed record in the canon repository; canon fixes found are listed as candidates in that record, not applied. PASS.
11. House style in the prose written | no `...`, long dash or ellipsis in `CLAUDE.md`, `AGENTS.md`, the stamp or the record. PASS.
12. Doc sync: `CLAUDE.md` and the contrib record affected; `README.md` (still says the project is a bootstrap that does not build) and `docs/BOOTSTRAP_HANDOFF.md` unchanged and still accurate; no document registry is declared. PASS.
13. Installed-plugin warning `SZA-CANON06` (the record resolves under the installed canon). EXEMPT: the installed plugin updates only when the canon repository publishes the record, which a project session does not do; the record exists and resolves from the canon checkout (item 8).
14. No application build exists, so no build or test command ran. EXEMPT: out-of-scope, the skeleton and the first build are S0002; not built, not tested.

### Action items

None for this ticket. Carried, each with its carrier in the open questions: the owner decisions (S0007), the parity inventory form (S0003), the contract declarations (S0002, S0005). For a canon session: the three candidate core edits listed in the contrib record, and the publication of that record.

### Manual / on-target

None open.
