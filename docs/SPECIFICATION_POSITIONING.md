# Positioning - the one source every external surface is written from

The positioning source of Filler (`SITE-REPRESENTATION` rules 1 and 2, S0040). It holds what the product is for, as an ordered
list, and names the surfaces that are written from it. A surface is never written from another surface: where two disagree,
this file decides which one is wrong. **Change this file first**, then the surfaces, then the anchors of
`tools/site/positioning-surfaces.json`, and run `tools/site/check-positioning.ps1`.

Provenance of the list below: taken on 2026-11-14 (S0040, an unattended assumption the owner may overrule) from the order that
the landing, the README opening and the three listing sources already shared when the check was written. It states the product
as the owner described it (`CLAUDE.md` section 1); it adds no function. The pillars FastMediaSorter's own positioning file lists
are not this product's.

## 1. What the product is

Filler fills the free space of a storage device with temporary files and then deletes them again, and deletes only the files
it wrote. One purpose, in a phone app and a Wear OS app under the one application id `com.sza.filler`.

## 2. The five pillars

Listed in this order by every surface that lists what Filler does. Each pillar has an id (the bold word), which the anchors
file and the check use; the id is never shown to a reader.

1. **choose** - Choose where, keep room. The volume or folder is picked in the Android folder picker, or the run starts in
   Filler's own folder; Filler shows the free space it measured and keeps part of it free for the system.
2. **follow** - Follow a run, stop at any moment. How much is written, the percentage and the time left are in view; a stop
   deletes the files written so far.
3. **cleanup** - Clean up, always. Only the files Filler wrote are deleted, from a list it keeps, and what is left after a stop,
   a write error, a restart or a removed memory card is offered for deletion as soon as the storage is back.
4. **schedule** - Fill on a schedule. On the phone, at a set time with the app closed, once a day at most, every run listed.
5. **watch** - Fill from a watch, on any device. The Wear OS app fills its own folder on the watch and keeps going with the
   screen dark; the phone app works with touch, keyboard, mouse and D-pad.

## 3. How to use this file

- **Keep the order.** A surface that lists the pillars lists them 1 to 5. Every surface below names all five.
- **Carry claims, not sentences.** Each surface has its own genre and length; the three languages of a surface say the same
  thing in the same order.
- **Privacy and permissions are not a pillar.** They are the standing statement that follows the pillars on every surface
  that has room for it (`SITE-REPRESENTATION` rule 12), compared by `tools/site/check-site-facts.ps1`.
- **Limits stand beside their function** (rule 5): the schedule "on the phone", the watch "on a Wear OS watch".

## 4. Surfaces

The set the check holds; the anchor phrases of each are in `tools/site/positioning-surfaces.json`. The store listing has no
exception to the order (no store policy asks it to name a different function first).

| Surface | File |
| --- | --- |
| Landing, English (the root address) | `site/index.html` |
| Landing, Russian | `site/index-ru.html` |
| Landing, Ukrainian | `site/index-uk.html` |
| README opening (the text before the first second-level heading) | `README.md` |
| Play listing, English (the full description) | `docs/play/PLAY_LISTING.md` |
| Play listing, Russian | `docs/play/PLAY_LISTING-ru.md` |
| Play listing, Ukrainian | `docs/play/PLAY_LISTING-uk.md` |

The Play Console fields are copies of the listing sources, so the console follows the sources and has no row of its own. The
privacy pages, the not-found pages and `docs/play/PLAY_DATA_SAFETY.md` list no pillar and are not surfaces of this file.
