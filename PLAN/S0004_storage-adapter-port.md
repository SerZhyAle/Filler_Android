# S0004 - Port local storage adapter

**Ticket:** S0004
**Status:** BlockByOtherTask
**Status note:** Blocker: S0003 - complete the preceding Filler project step before this ticket.
**Priority:** 60
**Tier:** 3 - Moderate
**Complexity:** hard - removable storage and ownership-safe cleanup
**Depends on:** S0003

## Goal

Port the completed FastMediaSorter S4521 local storage integration and its tests to the standalone application, rechecking the final upstream source. Preserve access validation, measured free space, persisted permissions, safe session-file ownership, cleanup and recovery. Do not broaden access to unsupported locations or delete unrelated files.

## Acceptance

The adapter integrates with the independent engine, passes ported automated coverage where possible, and records the removable-media and interruption cases requiring real-device verification. Never edit the upstream project.

## Upstream default destination handoff

Port FastMediaSorter's app-owned Downloads destination on primary storage, which requires no folder-picker grant. Preserve the picked-document-tree path for other local volumes. Keep the journal ownership checks, interruption recovery, reserve measurement and protection of unrelated files for both paths. Review the upstream AppFillerStorage implementation and its tests when porting.

### 3.3 Owner inputs (Approval gate)

- **Related tickets:** S0003; FastMediaSorter S4521.
