package com.sza.filler.ui.theme

import androidx.appcompat.app.AppCompatDelegate
import com.sza.filler.R
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

// Unit tests for ColorThemePrefs (FILLER-0067): verifies mode normalization, night-mode mapping,
// and custom accent ThemeOverlay resolution across all 9 supported FastMediaSorter themes.
class ColorThemePrefsTest {

    @Test
    fun `normalizeValue handles case whitespace and unknown values`() {
        assertEquals("AUTO", ColorThemePrefs.normalizeValue(null))
        assertEquals("AUTO", ColorThemePrefs.normalizeValue("unknown"))
        assertEquals("LIGHT", ColorThemePrefs.normalizeValue(" light "))
        assertEquals("DARK", ColorThemePrefs.normalizeValue("Dark"))
        assertEquals("DARK_GREEN", ColorThemePrefs.normalizeValue("dark_green"))
        assertEquals("LIGHT_BLUE", ColorThemePrefs.normalizeValue("LIGHT_BLUE"))
        assertEquals("LIGHT_RED", ColorThemePrefs.normalizeValue("light_red"))
    }

    @Test
    fun `toNightMode maps light dark and custom accent themes`() {
        assertEquals(AppCompatDelegate.MODE_NIGHT_FOLLOW_SYSTEM, ColorThemePrefs.toNightMode("AUTO"))
        assertEquals(AppCompatDelegate.MODE_NIGHT_NO, ColorThemePrefs.toNightMode("LIGHT"))
        assertEquals(AppCompatDelegate.MODE_NIGHT_NO, ColorThemePrefs.toNightMode("LIGHT_GREEN"))
        assertEquals(AppCompatDelegate.MODE_NIGHT_NO, ColorThemePrefs.toNightMode("LIGHT_BLUE"))
        assertEquals(AppCompatDelegate.MODE_NIGHT_NO, ColorThemePrefs.toNightMode("LIGHT_RED"))
        assertEquals(AppCompatDelegate.MODE_NIGHT_YES, ColorThemePrefs.toNightMode("DARK"))
        assertEquals(AppCompatDelegate.MODE_NIGHT_YES, ColorThemePrefs.toNightMode("DARK_GREEN"))
        assertEquals(AppCompatDelegate.MODE_NIGHT_YES, ColorThemePrefs.toNightMode("DARK_BLUE"))
        assertEquals(AppCompatDelegate.MODE_NIGHT_YES, ColorThemePrefs.toNightMode("DARK_RED"))
    }

    @Test
    fun `overlayResId resolves only the six custom accent themes`() {
        assertNull(ColorThemePrefs.overlayResId("AUTO"))
        assertNull(ColorThemePrefs.overlayResId("LIGHT"))
        assertNull(ColorThemePrefs.overlayResId("DARK"))
        assertEquals(R.style.ThemeOverlay_Filler_DarkGreen, ColorThemePrefs.overlayResId("DARK_GREEN"))
        assertEquals(R.style.ThemeOverlay_Filler_DarkBlue, ColorThemePrefs.overlayResId("DARK_BLUE"))
        assertEquals(R.style.ThemeOverlay_Filler_DarkRed, ColorThemePrefs.overlayResId("DARK_RED"))
        assertEquals(R.style.ThemeOverlay_Filler_LightGreen, ColorThemePrefs.overlayResId("LIGHT_GREEN"))
        assertEquals(R.style.ThemeOverlay_Filler_LightBlue, ColorThemePrefs.overlayResId("LIGHT_BLUE"))
        assertEquals(R.style.ThemeOverlay_Filler_LightRed, ColorThemePrefs.overlayResId("LIGHT_RED"))
    }

    @Test
    fun `ALL_MODES lists all nine themes in picker order`() {
        assertEquals(
            listOf("AUTO", "LIGHT", "DARK", "DARK_GREEN", "DARK_BLUE", "DARK_RED", "LIGHT_GREEN", "LIGHT_BLUE", "LIGHT_RED"),
            ColorThemePrefs.ALL_MODES,
        )
    }
}
