# Port ledger and drift check

The product copies FastMediaSorter's Filler instead of sharing it, so a change made there after the copy has to be
found and either carried or decided (`docs/SPECIFICATION_SYNC_MODEL.md`). The ledger `docs/port-ledger.jsonl` records what was
copied from which source version; these scripts keep it honest. They read the FastMediaSorter checkout and never
write to it. The format is the catalog contract `PORT-LEDGER` 0.1; these scripts follow its text and share no code
with the sibling products' tools.

| Script | When | What it does |
| --- | --- | --- |
| `record-port.ps1 -Source <src path> -Destination <path here>` | right after porting a file | adds the row with the source's SHA-256 as it is now (`-Sha256` imports a hash recorded earlier; `-Kind partial -Region ..` for part of a file; `-WithDestinationHash` to see a later hand edit as `LOCAL EDIT`) |
| `record-port.ps1 .. -Refresh` | after carrying a newer version | the row takes the source's current hash, gets `carriedOn`, loses any decision |
| `check-drift.ps1 [-Json] [-ShowAll]` | the release preflight, before any parity claim | one line per row not in step, the status counts, a verdict line; exit 0 in step, 1 an uncovered row, 2 could not verify |
| `decide-drift.ps1 -Source <src path> -Note ".."` | a change is deliberately not carried | writes the decision next to the row, pinned to the source version read now |
| `pass-start.ps1 [-NoFile]` | the start of every session (hook) | the same check; an uncovered row no ticket names yet opens one Draft ticket through `spec-draft`; always exit 0 |
| `test-port-ledger.ps1` | release; after editing these scripts | the `PORT-LEDGER` conformance cases and the script paths on a throw-away tree under `temp/` |

Paths are relative to their repository root with forward slashes. Run every script as
`pwsh -NoProfile -File tools/port-ledger/<script>.ps1 ..` from the repository root.

## Statuses

`OK` (the source hash equals the row's), `DECIDED` (it differs and a decision covers the current hash), `DRIFT` (it
differs and nothing covers it), `SOURCE GONE`, `NO DEST` (a row with both gets `SOURCE GONE`), `LOCAL EDIT` (the
destination differs from `destinationSha256`; informative, never failing) and `NEW SOURCE` (a file inside the scope
file with no row and no exclusion). An empty ledger is in step. A decision stops covering a file the moment the
source changes again.

## The source root

An explicit `-SourceRoot`, then `SZA_PORT_SOURCE_ROOT`, then the portfolio registry path of the project that
`.sza-profile.json` `extraction.sourceProject` names (`fms-a`). No path is kept in a tracked file. A source root that
cannot be found is exit 2, never 0.

## The scope file

`docs/port-scope.json`: `include` (globs over source paths; `**` crosses directories) and `exclude` (objects with
`glob` and a required `reason`). It closes the gap of a ledger that lists only what was ported: a file added to the
source later inside `include` shows as `NEW SOURCE`.

## The hook

`.claude/settings.json` registers one `SessionStart` hook; this table is its inventory.

| Hook | Event | Verdict | What it does |
| --- | --- | --- | --- |
| `tools/port-ledger/pass-start.ps1` | `SessionStart` (`startup`, `resume`, `clear`) | injects, files | prints one verdict line into the session; files one Draft ticket for a drift no ticket names; never fails the session |

The token `port-drift: <source> <status> <hash8>` in a ticket text under `PLAN/` is what stops a file being filed
twice. The self-test stubs the filing, so it opens no ticket.
