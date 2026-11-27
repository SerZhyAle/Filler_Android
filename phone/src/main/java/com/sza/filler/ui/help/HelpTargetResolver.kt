package com.sza.filler.ui.help

// Ported from FastMediaSorter (ui/common/help/HelpTargetResolver.kt, CONTEXT-HELP rule 17). Deliberate differences
// (S0028): the target is a help id with its form and anchor, not a bundled page and its site twin, because this app's
// help is a layer drawn from its strings (no asset page, no locale folder, no site URL); and no sub-page lookup (see
// HelpMap.kt). The inherit walk, the cycle guard and the "none means no help" rule are the source's. Deliberate
// difference (S0041): the anchor of an `inherit` row is honoured, nearest row first (the asked surface's own row, then its
// parents', ending at the row that holds the help), as items A and K of CONTEXT-HELP 0.2/0.3 say; the source reads only the
// anchor of the row where the walk ends, so an anchor set on an inherit row is never opened there.

/** Where a help request lands: the help id, the form it is shown in, and the element anchor if any. */
data class HelpTarget(
    val helpId: String,
    val form: HelpForm,
    val anchor: String?,
)

/**
 * The one resolver every F1 handler and every `?` action calls (contract `CONTEXT-HELP` rule 17): surface id and
 * optional element anchor in, the help target out.
 */
class HelpTargetResolver(private val map: HelpMap) {

    /** The help of [surfaceId], or null when the surface has no help of its own or inherited. */
    fun resolve(surfaceId: String, elementAnchor: String? = null): HelpTarget? {
        val walk = followInherit(map.surface(surfaceId)) ?: return null
        val row = walk.end
        val usable = row.form != HelpForm.NONE && row.form != HelpForm.INHERIT
        val helpId = row.help
        return if (usable && helpId != null) HelpTarget(helpId, row.form, elementAnchor ?: walk.anchor) else null
    }

    /** True when [surfaceId] reaches help, so an F1 handler knows whether to take the key. */
    fun hasHelp(surfaceId: String): Boolean = resolve(surfaceId) != null

    /** The row where an inherit walk ends and the anchor the walk found: the first non-blank anchor, nearest row first. */
    private class Walk(val end: HelpSurface, val anchor: String?)

    /** Walks `inherit` rows up to the first row that is not one; a cycle or a missing parent ends at null. */
    private fun followInherit(start: HelpSurface?): Walk? {
        val visited = mutableSetOf<String>()
        var row = start
        var anchor: String? = null
        while (row != null && row.form == HelpForm.INHERIT) {
            if (anchor == null) anchor = row.anchor?.takeIf { it.isNotBlank() }
            row = if (visited.add(row.id)) row.parent?.let(map::surface) else null
        }
        return row?.let { Walk(it, anchor ?: it.anchor?.takeIf { a -> a.isNotBlank() }) }
    }

    companion object {
        const val MAP_ASSET = "help/help-map.json"
    }
}
