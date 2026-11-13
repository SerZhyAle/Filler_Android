# S0005 - Port Filler user flow

**Ticket:** S0005
**Status:** BlockByOtherTask
**Status note:** Blocker: S0004 - complete the preceding Filler project step before this ticket.
**Priority:** 60
**Tier:** 3 - Moderate
**Complexity:** hard - user flow, lifecycle and input accessibility
**Depends on:** S0004

## Goal

Port the full final FastMediaSorter S4521 user-facing Filler flow and its resources into the independent phone app, after re-inventorying the completed source. Settle placement and behaviour from upstream and applicable UI rules before implementation.

## Acceptance

Users can choose an available local volume and folder, inspect free space and reserve, confirm and monitor an operation, cancel, understand failures and retry incomplete cleanup. Preserve all final upstream functionality, translations, accessibility and keyboard, D-pad and mouse support, including both orientations. Maintain lifecycle-safe work and relevant help. Document any remaining device checks.

## Upstream default destination handoff

On first opening, select the writable app-owned Downloads directory on internal storage and make Start the obvious next action. Keep the explicit start confirmation, free-space and reserve display, optional folder choice and recovery UI. Apply the same flow in both orientations and for keyboard, D-pad and mouse; show an actionable fallback if the default location is unavailable. Re-inventory the FastMediaSorter Filler implementation and resources before porting.

### 3.3 Owner inputs (Approval gate)

- **Related tickets:** S0004; FastMediaSorter S4521.
