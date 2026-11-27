# Documentation checks

`DOC-INTERNAL-QUALITY` rules 1, 2, 3, 5 and 6 over the public corpus: `README.md`, every file under `docs/`, and the
Markdown files under `tools/`. The boundary is declared in `docs.config.json` and never inferred; only files git tracks
or could track are in it, so a git-ignored file is outside. Since FILLER-0071 (`REPO-LAYOUT` 0.12 rule 8,
`DOC-INTERNAL-QUALITY` 0.14 item AA) the agent rules, the `.claude/` rules, the contract pointers, the registry and the
release ledger are local-only and gitignored: they stay on disk, outside this corpus and outside the primary registry,
and the canon compliance gate reads them from disk. Rule 4 (generated documents) is held by the generator and the check each generated record of the registry
names; rule 7 (offline safety) is held by reading: the corpus carries no remote script, font or pixel and no `http:`
link.

| Script | When | What it does |
| --- | --- | --- |
| `check-docs.ps1 [-Check registry\|links\|style\|assets\|all]` | after any edit to the corpus, between releases | runs the checks below; `all` (the default) also runs the harness `document_registry/validate` and ends with `docs-check: <WORD>` |
| `test-docs.ps1 [-Filter <text>]` | release; after editing these scripts | 27 cases on throw-away git trees: each check passes clean and fails on its own defect, an unreadable input is exit 2; `-Filter` runs the cases whose name contains the text and counts the rest as skipped |

- **registry** - every record of `docs/DOCUMENT_REGISTRY.jsonl` carries the harness fields, a topic, a product area and
  an update trigger; a generated record names its generator and its check; every declared pattern matches a file;
  every corpus file has exactly one record (or an `ignore` entry with a reason of four words or more in
  `docs.config.json`, empty today).
- **links** - relative Markdown links resolve to a file or folder and a `#fragment` to a heading of the target (GitHub's
  slug) or an explicit `name=` or `id=` anchor. Links inside a record marked `"archive": true` are not judged (a
  frozen archive); links into it are.
- **style** - no three dots, no ellipsis character, no em or en dash in Markdown prose; fenced blocks, inline code and
  link targets are removed first.
- **assets** - image links and image paths written in inline code resolve to a tracked file; a bare file name resolves
  to any tracked file of that name. An asset that only exists git-ignored is refused.

A new document either matches an existing record's glob or gets a record of its own; `generated: true` marks a render
that is regenerated, never hand-edited, and says how in `generator` and `check`. The optional `contract` field names
the contract id and section a document describes (`DOC-INTERNAL-QUALITY` item X); the gate does not read it.

There is no baseline file: the gate keeps no accepted debt, so a finding is fixed or the file is recorded or ignored
with a reason. Exit codes: 0 PASS, 1 FAIL, 2 COULD NOT VERIFY (unreadable configuration or registry, no git work tree,
the harness validator missing). The last line on stdout is the verdict line.

Run each script as `pwsh -NoProfile -File tools/docs/<script>.ps1 ..` from the repository root.
