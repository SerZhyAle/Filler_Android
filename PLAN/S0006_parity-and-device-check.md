# S0006 - Verify Filler parity and recovery

**Ticket:** S0006
**Status:** BlockByOtherTask
**Status note:** Blocker: S0005 - complete the preceding Filler project step before this ticket.
**Priority:** 50
**Tier:** 3 - Moderate
**Complexity:** hard - parity audit and real storage verification
**Depends on:** S0005

## Goal

Audit the standalone product against the completed FastMediaSorter S4521 spec, code, resources and tests. Close gaps in the port, maintain an explicit parity inventory and execute the applicable automated checks.

## Acceptance

Document evidence for independent installation and all completed upstream behaviour. On an authorized real device, verify local and removable storage, safe reserve and unrelated files, cancellation, loss of access, disconnection, restart and retry of cleanup. If a real-device scenario has not happened, leave it as an open manual check rather than reporting it passed. Observe the applicable device permissions and test rules.

## Upstream default destination handoff

Include first launch without a folder grant, Start confirmation, choosing another local folder, insufficient space, interrupted writes and restart cleanup in the parity and device checks. Verify that unrelated files remain intact and the displayed destination identifies the app-owned Downloads folder. Record checks that have not been run as open manual or release checks.

### 3.3 Owner inputs (Approval gate)

- **Related tickets:** S0005; FastMediaSorter S4521.
