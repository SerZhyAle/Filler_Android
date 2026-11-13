# PACKAGE-VERSIONING - pointer

| Field | Value |
| --- | --- |
| **Id** | `PACKAGE-VERSIONING` |
| **Version** | 0.6, draft (registry, read 2026-11-10) |
| **Home** | shared contracts catalog, `package-versioning/` |
| **Owner** | FastMediaSorter Android |
| **Role here** | consumer, Android profile - versionName and versionCode of the phone package |

What this repository owes:

- Derive versionName and versionCode as the contract says, mechanically, from one instant; never hand-bump.
  `buildSrc` holds the one implementation (rules 1 to 3, with the phone family's band map
  `floor(minute / 10)`), `phone/build.gradle.kts` applies it, and every build stamps itself from one clock
  reading (rule 6). No checked-in sentinel exists, so rules 7 and 8 have nothing to drift.
- A release orchestrator pins the pair with `-Pfiller.versionName` and `-Pfiller.versionCode`, together or not
  at all; a pair that does not describe one instant is refused at build time (rule 5). In PowerShell the
  arguments are quoted, or the shell splits them at the dot.
- Proof of section 4 rung 2: the fixed-instant vectors in `buildSrc/src/test` render the contract's own
  example instant, the band edges, the ordering across slot, day, year and leap-day boundaries, and refuse
  invalid instants and pairs.
- Before the first package ships: the Filler phone family joins the rule 3 band table as a MINOR amendment
  written in the catalog first. It registers the published application id, which the owner has not chosen, so
  it is carried to S0007 and proposed through the canon session, never written from here. Until then the
  build refuses every release packaging task (S0002).
