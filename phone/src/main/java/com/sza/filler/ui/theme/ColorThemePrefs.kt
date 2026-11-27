package com.sza.filler.ui.theme

import android.app.Activity
import android.content.Context
import androidx.appcompat.app.AppCompatDelegate
import com.sza.filler.R
import java.util.Locale

// Ported from FastMediaSorter (core/theme/ColorThemePrefs.kt, S0569; FILLER-0067 here). Deliberate differences:
// - Filler has no DataStore or Timber dependency, so SharedPreferences is the sole synchronous store;
// - applies ThemeOverlay.Filler.* overlays (matching the six FastMediaSorter custom accent palettes);
// - exposes ALL_MODES in the order of R.array.color_theme_options for the phone toolbar theme picker.

/**
 * Synchronous store for the app-wide colour theme applied before any Activity inflates.
 *
 * Raw values: "AUTO" (follow device night-mode, default), "LIGHT" (force light), "DARK" (force dark),
 * plus the six custom accent themes "DARK_GREEN", "DARK_BLUE", "DARK_RED", "LIGHT_GREEN", "LIGHT_BLUE",
 * and "LIGHT_RED" - each pins a fixed night mode and layers a ThemeOverlay onto each Activity.
 */
object ColorThemePrefs {
    private const val FILE_NAME = "color_theme_prefs"
    private const val KEY_COLOR_THEME = "color_theme"
    const val DEFAULT = "AUTO"

    val ALL_MODES: List<String> = listOf(
        "AUTO",
        "LIGHT",
        "DARK",
        "DARK_GREEN",
        "DARK_BLUE",
        "DARK_RED",
        "LIGHT_GREEN",
        "LIGHT_BLUE",
        "LIGHT_RED",
    )

    fun normalizeValue(value: String?): String = when (value?.trim()?.uppercase(Locale.ROOT)) {
        "LIGHT" -> "LIGHT"
        "DARK" -> "DARK"
        "DARK_GREEN" -> "DARK_GREEN"
        "DARK_BLUE" -> "DARK_BLUE"
        "DARK_RED" -> "DARK_RED"
        "LIGHT_GREEN" -> "LIGHT_GREEN"
        "LIGHT_BLUE" -> "LIGHT_BLUE"
        "LIGHT_RED" -> "LIGHT_RED"
        else -> DEFAULT
    }

    fun toNightMode(value: String): Int = when (normalizeValue(value)) {
        "LIGHT", "LIGHT_GREEN", "LIGHT_BLUE", "LIGHT_RED" -> AppCompatDelegate.MODE_NIGHT_NO
        "DARK", "DARK_GREEN", "DARK_BLUE", "DARK_RED" -> AppCompatDelegate.MODE_NIGHT_YES
        else -> AppCompatDelegate.MODE_NIGHT_FOLLOW_SYSTEM
    }

    fun setMode(context: Context, value: String) {
        val normalizedValue = normalizeValue(value)
        context.applicationContext
            .getSharedPreferences(FILE_NAME, Context.MODE_PRIVATE)
            .edit()
            .putString(KEY_COLOR_THEME, normalizedValue)
            .apply()
    }

    fun getMode(context: Context): String = normalizeValue(
        context.applicationContext
            .getSharedPreferences(FILE_NAME, Context.MODE_PRIVATE)
            .getString(KEY_COLOR_THEME, DEFAULT),
    )

    fun applyMode(value: String) {
        AppCompatDelegate.setDefaultNightMode(toNightMode(normalizeValue(value)))
    }

    fun overlayResId(mode: String): Int? = when (normalizeValue(mode)) {
        "DARK_GREEN" -> R.style.ThemeOverlay_Filler_DarkGreen
        "DARK_BLUE" -> R.style.ThemeOverlay_Filler_DarkBlue
        "DARK_RED" -> R.style.ThemeOverlay_Filler_DarkRed
        "LIGHT_GREEN" -> R.style.ThemeOverlay_Filler_LightGreen
        "LIGHT_BLUE" -> R.style.ThemeOverlay_Filler_LightBlue
        "LIGHT_RED" -> R.style.ThemeOverlay_Filler_LightRed
        else -> null
    }

    fun applyThemeOverlay(activity: Activity) {
        val resId = overlayResId(getMode(activity)) ?: return
        activity.theme.applyStyle(resId, true)
    }

    fun reset(context: Context) {
        context.applicationContext
            .getSharedPreferences(FILE_NAME, Context.MODE_PRIVATE)
            .edit()
            .clear()
            .apply()
        AppCompatDelegate.setDefaultNightMode(toNightMode(DEFAULT))
    }

    fun applySavedMode(context: Context) {
        val prefs = context.applicationContext.getSharedPreferences(FILE_NAME, Context.MODE_PRIVATE)
        val rawValue = prefs.getString(KEY_COLOR_THEME, DEFAULT)
        val value = normalizeValue(rawValue)
        if (rawValue != value) {
            prefs.edit().putString(KEY_COLOR_THEME, value).apply()
        }
        AppCompatDelegate.setDefaultNightMode(toNightMode(value))
    }
}
