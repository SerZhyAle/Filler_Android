package com.sza.filler.ui.help

import org.json.JSONArray
import org.json.JSONObject

// Ported from FastMediaSorter (ui/common/help/HelpMap.kt, CONTEXT-HELP). Deliberate differences (S0028):
// - parsed with the platform's org.json, the source's Gson is not a dependency of this app;
// - no sub-pages: the source's settings tabs and player sub-views have no counterpart in a one-screen app, and a
//   map member this reader does not know is ignored as before (contract section 3);
// - no page template: the one help entry of this app is a layer (form "layer"), whose text is the app's strings.

/** Form of the help a surface offers (contract `CONTEXT-HELP` rule 4). */
enum class HelpForm {
    PAGE,
    LAYER,
    BOTH,
    INHERIT,
    NONE,
    ;

    companion object {
        fun parse(value: String?): HelpForm? = entries.firstOrNull { it.name.equals(value, ignoreCase = true) }
    }
}

/** One row of the help map: one surface and what its help is. */
data class HelpSurface(
    val id: String,
    val name: String,
    val form: HelpForm,
    val help: String?,
    val anchor: String?,
    val parent: String?,
    val reason: String?,
)

/** The shipped help map (`assets/help/help-map.json`, contract `CONTEXT-HELP` rule 17). */
data class HelpMap(
    val schemaVersion: Int,
    val surfaces: List<HelpSurface>,
) {
    private val byId: Map<String, HelpSurface> = surfaces.associateBy { it.id }

    fun surface(id: String): HelpSurface? = byId[id]

    companion object {
        /**
         * Parses the map. Unknown members are ignored and a row with an unknown form is skipped, so a map
         * written against a later schema stays readable (contract section 3).
         */
        fun parse(json: String): HelpMap {
            val root = JSONObject(json)
            val rows = root.optJSONArray("surfaces") ?: JSONArray()
            val surfaces = (0 until rows.length()).mapNotNull { index -> rows.optJSONObject(index)?.let(::parseSurface) }
            return HelpMap(
                schemaVersion = root.optString("schemaVersion").toIntOrNull() ?: 1,
                surfaces = surfaces,
            )
        }

        private fun parseSurface(obj: JSONObject): HelpSurface? {
            val id = obj.text("id")
            val form = HelpForm.parse(obj.text("form"))
            if (id.isNullOrBlank() || form == null) return null
            return HelpSurface(
                id = id,
                name = obj.text("name").orEmpty(),
                form = form,
                help = obj.text("help"),
                anchor = obj.text("anchor"),
                parent = obj.text("parent"),
                reason = obj.text("reason"),
            )
        }

        private fun JSONObject.text(name: String): String? =
            if (isNull(name)) null else opt(name)?.takeIf { it is String || it is Number }?.toString()
    }
}
