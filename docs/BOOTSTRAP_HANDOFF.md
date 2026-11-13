# Filler mobile bootstrap handoff

FastMediaSorter S4523 requested a standalone Android project, initial tickets, and enrollment in the same portfolio scheduler as `streams-mob` and `tourist-mob`. The owner requested the full functionality of FastMediaSorter's Filler, not a partial or redesigned substitute. This folder is a bootstrap; it is not an installable app or a release.

## Upstream and parity

FastMediaSorter S4521 (`P:/ANDROID/FastMediaSorter_mob_v2/PLAN/S4521_local-storage-filler.md`) is In Progress. Re-inventory its final specification, code, resources and tests before the port. At bootstrap, its goals include a local volume and folder choice, measured free space and reserve, writing temporary files, progress and cancellation, safely deleting only files from the operation, and retryable cleanup after disconnection or restart. Preserve all final upstream behaviour and tests. Never delete or alter the FastMediaSorter implementation from this project.

## Execution and boundaries

- Standalone phone product and independent release lifecycle; do not assume a watch product.
- Adopt the SZA shared harness by reference. The `.sza-canon.json` stamp establishes the reference for scheduler discovery; S0001 must finish and validate full adoption before claiming compliance.
- The source feature is still changing. Port tickets must check S4521's completion and defer rather than claiming full parity from the initial snapshot.
- The owner has not chosen the published application ID, signing, release channel, license, public remote or site. Leave those as decisions for release preparation; never publish automatically.
- The first project tickets are the authoritative backlog. Follow their release queue order; preserve the upstream reference in follow-on tasks.
