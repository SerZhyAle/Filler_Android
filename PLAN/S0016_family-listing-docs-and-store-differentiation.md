# S0016_family-listing-docs-and-store-differentiation

**Status:** Draft
**Created:** 2026-11-13
**Complexity:** medium - listing, docs and site-family inputs for the release decisions

## 0. Owner request (verbatim)

[Owner, 2026-11-13, first message]

Так.
Идея этого приложения была чтобы весь функционал по суб-программы Filler телефоне (любом андроид устройстве), часах , который реализован в FMS_A был представлен в виде самостоятельных приложений android,  которые могут заинтересовать пользователя, которому не интересен весь остальной функционал FMS_A
Но при этом эти приложения не только выглядят более-менее одинаково, но и развиваются вместеи новый/исправленный функционал обновляется/исправляется в них паралельно, они пересекаются по документации, принадлежат общему семейству программ и связаны канонами и контрактами.
Исследуй всё ли верно в мположениях?

[Owner, 2026-11-13, request after the research report]

Создай такие спецификации в рамках этого продукта, которые приведут его к вышеописанному заказанному состоянию

[Owner, 2026-11-13, correction request]

правильно ли я понял, что по производству всех заказаных задач
это приложение будет иметь весь функционал по соответствующей суб-программы телефона (любом андроид устройстве), часах , который реализован в FMS_A был представлен в виде самостоятельных приложений android,  которые могут заинтересовать пользователя, которому не интересен весь остальной функционал FMS_A
Но при этом эти приложения будут выглядеть более-менее одинаково, развиваться вместе и новый/исправленный функционал обновляется/исправляется в них паралельно, они пересекаются по документации, принадлежат общему семейству программ и связаны канонами и контрактами.
Поправь спецификации чтобы было именно так


## 1. Problem

The owner wants the apps to attract users who do not care for the rest of FastMediaSorter, to share documentation with it and to belong to one visible family. Today the Filler has no site, no help, no privacy page and no store text, it is missing from the family site map, and its documentation exists only inside FastMediaSorter's documents. The portfolio's own risk note (FastMediaSorter S4070 section 7) says the store policy on repetitive content works at account level, so a store app that duplicates a FastMediaSorter sub-program can put every app of the account at risk, and the Filler is the closest duplicate of the whole family.

## 2. Done criteria

1. A documentation overlap map in `docs/` names which FastMediaSorter Filler documents (feature entry, help, how-to, translations) are the source of this product's README, help and site pages (phone and watch), and the rule that keeps them in step (a line in the sync model of S0011 or a citation of it). Any text that becomes a user surface is written as a shipped, present-tense fact (canon invariant 17).
2. A one-page listing brief compares the Filler's store entry with FastMediaSorter's: start screen, description, screenshots and the one reason to install each. It cites the store policy text with the date it was read; a policy that was not read is not described.
3. The Filler's row for the family site map is prepared as a proposal for the owner of that contract; it is filed in the catalog only after the store name is chosen (S0007).
4. A hand-off note for the FastMediaSorter owner lists what is owed on that side - a link from FastMediaSorter's documents and site to the Filler once it is public (the form of FastMediaSorter S4279 for StreamsPlayer) and the assumption of section 3.2 that the Filler stays in both products, which the sync model of S0011 presupposes - as text only; no FastMediaSorter file is changed from here. The note also points to the catalog proposal `_meta/PROPOSAL-2026-11-13-new-contract-source-port-ledger.md`, whose rule 8 (the source's side of the sync) is the owner's decision.
5. The inputs for S0007 (store name, branding, channel) are written into S0007's owner-input list so that it asks them once.
6. `pwsh -NoProfile -File tools/harness.ps1 spec_catalog/validate` exits 0.

## 3. Approach

### 3.1 Scope

In: the overlap map, the listing brief, the site-map proposal, the hand-off note, the inputs for S0007. Out: publishing anything, choosing the store name, the channel or the application id (S0007), editing the FastMediaSorter checkout, building a site.

### 3.4 Evidence read on 2026-11-13

- FastMediaSorter S4070 section 7 (Tourist): the repetitive-content policy risk applies to the whole account; its mitigation was a different start screen, description and screenshots.
- The family site map lists FastMediaSorter and StreamsPlayer among others; neither Tourist nor the Filler is in it.
- Precedents for the FastMediaSorter-side decision: streams stay in both products (owner, 2026-10-16, FastMediaSorter S4065); the Tourist hike kit is still open (FastMediaSorter S4467). No ticket exists for the Filler.
- `CLAUDE.md` section 3: store name, branding, channels, site and privacy page are open owner decisions of S0007.

### 3.2 Open questions

1. **How is the account-level policy risk handled before the first store listing?**
   - A: the listing differs from FastMediaSorter's in start screen, description and screenshots, built around the single purpose.
   - B: the first channel is chosen to avoid the store until the policy has been read. Carrier: S0007 (channel).
   - **Resolved 2026-11-13 (owner): A** - accepted in the recommendations table of the public presence (S0007 `### Owner decisions (2026-11-13)`); the listing source is `docs/play/PLAY_LISTING.md`.

### Assumed (unattended, 2026-11-13)

- **The Filler stays inside FastMediaSorter after the standalone release.** The owner states that the apps develop together and that new and corrected functionality is updated in them in parallel, which presupposes that both exist; this is the choice made for streams (FastMediaSorter S4065, 2026-10-16), with double maintenance and the sync of S0011. Alternative: a staged hand-over, FastMediaSorter pointing its users to the standalone app. The FastMediaSorter-side ticket belongs to the FastMediaSorter owner and is not created here. Owner may overrule.

### 3.3 Owner inputs (Approval gate)

- **Related tickets:** S0007, S0011, S0014; FastMediaSorter S4070, S4279, S4467.
