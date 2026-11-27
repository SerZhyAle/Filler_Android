# Agent hooks

The agent hooks this repository registers. A hook fires inside a tool call nobody is reading, so each one is listed
here in the change that registers it. Hooks registered in a machine-local settings file are not listed: they are not
version-controlled and belong to the machine.

## Inventory

| Script | Registered in | Event | What it does |
| --- | --- | --- | --- |
| `pass-start.ps1` | `.claude/settings.json` | `SessionStart` (`startup`, `resume`, `clear`) | runs the port-ledger drift check of `tools/port-ledger/` at the start of every session and every `pq` pass; an undecided drift files one Draft ticket through the `spec-draft` flow, and the line `pass-start: PASS (..)` is the verdict; the hook ends with `|| true`, so it never blocks a session (S0011, `docs/SPECIFICATION_SYNC_MODEL.md`) |
