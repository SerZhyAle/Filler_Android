# S0008 - Default destination and start flow

**Ticket:** S0008
**Status:** BlockByOtherTask
**Status note:** Blocker: S0005 - complete the Filler user-flow port before checking standalone default-destination parity.
**Created:** 2026-11-11
**Priority:** 50
**Tier:** 3 - Moderate
**Complexity:** medium - first-run behavior, storage access and recovery
**Depends on:** S0005

## 0. Owner request

Use a writable default folder so a new user can start Filler without first choosing a folder, and repeat the FastMediaSorter behavior in the standalone Filler application.

## 1. Problem

The first-run folder picker interrupts the operation and leaves new users unsure how to proceed. The standalone application needs an accessible default destination and a clear start action, while preserving the choice of another local folder.

## 2. Done criteria

- On a fresh launch without a document-tree grant, select the application's own Downloads directory on primary storage, display the actual destination, available space and reserve, and offer Start when it is safe to run.
- Start requires the existing explicit confirmation. Users can still choose another writable local folder, including on removable storage, and receive an actionable fallback if the default location or space measurement is unavailable.
- Preserve the free-space reserve, cancellation, interruption recovery and ownership-safe cleanup. Verify that unrelated files are not deleted and that interrupted cleanup remains retryable after restart.
- Check portrait and landscape, keyboard, D-pad and mouse interaction, and accessibility of the destination and Start action.
- Re-inventory FastMediaSorter's current Filler implementation and its tests before porting; S0004 and S0005 already carry the implementation handoff. Avoid duplicating work completed by those tickets.
- Record automated results and any unperformed real-device scenarios as open release or manual checks. Do not claim a build, test or device pass without evidence.

## 3. Approach

### 3.1 Scope

Complete and verify first-run parity with FastMediaSorter's Filler. The default is app-owned Downloads on internal storage, not a promise of unrestricted access to the shared Downloads folder. The independent application ID, release and branding decisions remain outside this ticket.

### 3.2 Open questions

None identified. Reassess if the upstream behavior or platform constraints change.

### 3.3 Owner inputs (Approval gate)

- **Related tickets:** Filler_mob S0004, S0005, S0006; FastMediaSorter S4521.
