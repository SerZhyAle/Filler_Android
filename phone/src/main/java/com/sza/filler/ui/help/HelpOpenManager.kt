package com.sza.filler.ui.help

import android.app.Activity
import android.content.Context
import android.util.Log
import android.view.View
import org.json.JSONException
import java.io.IOException

// Ported from FastMediaSorter (ui/common/help/HelpOpenManager.kt, CONTEXT-HELP rule 3). Deliberate differences
// (S0028): the answer is the layer of HelpLayer, not a page activity; there is no shortcut-dialog or portal fallback,
// because a surface without help has no help button and leaves F1 alone (hasHelp); the log is android.util.Log, this
// app has no Timber.

/** The one entry every F1 key and every help button calls: one surface id resolves to one form of help. */
object HelpOpenManager {

    private const val TAG = "FillerHelp"

    private val lock = Any()

    @Volatile
    private var resolver: HelpTargetResolver? = null

    /**
     * Opens the help of [surfaceId]. [focused] is the view that had the focus when F1 was pressed, or null for the help
     * button, which opens the beginning of the help (contract amendment item K); a focused element with its own entry
     * opens at that entry (rule 3). Returns false and opens nothing when the surface has no help.
     */
    fun open(activity: Activity, surfaceId: String, focused: View? = null): Boolean {
        val target = resolverOrNull(activity)?.resolve(surfaceId) ?: return false
        val entries = HelpLayerContent.entries(target.helpId)
        if (entries.isEmpty()) return false
        val anchor = focused?.id?.let { id -> entries.firstOrNull { it.viewId == id && it.anchor != HELP_ANCHOR }?.anchor }
        HelpLayer(activity, entries, anchor ?: target.anchor).show()
        return true
    }

    /** True when the help map gives [surfaceId] help that this app can show. */
    fun hasHelp(context: Context, surfaceId: String): Boolean {
        val target = resolverOrNull(context)?.resolve(surfaceId) ?: return false
        return HelpLayerContent.entries(target.helpId).isNotEmpty()
    }

    // A failed read is not cached: the next request retries instead of pinning "no help" for the process.
    private fun resolverOrNull(context: Context): HelpTargetResolver? =
        resolver ?: synchronized(lock) {
            resolver ?: loadResolver(context)?.also { resolver = it }
        }

    private fun loadResolver(context: Context): HelpTargetResolver? =
        try {
            val json = context.applicationContext.assets.open(HelpTargetResolver.MAP_ASSET).bufferedReader().use { it.readText() }
            HelpTargetResolver(HelpMap.parse(json))
        } catch (e: IOException) {
            Log.w(TAG, "Help map: bundled map unreadable", e)
            null
        } catch (e: JSONException) {
            Log.w(TAG, "Help map: bundled map malformed", e)
            null
        }

    /** The help button's own entry, never the target of the button or of F1 on it (amendment item K). */
    private const val HELP_ANCHOR = "help"
}
