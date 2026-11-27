package com.sza.filler.ui.common.widget

import android.content.Context
import android.content.res.ColorStateList
import android.graphics.drawable.InsetDrawable
import android.util.AttributeSet
import android.view.View
import androidx.activity.ComponentActivity
import androidx.annotation.DrawableRes
import androidx.appcompat.content.res.AppCompatResources
import androidx.core.content.res.use
import com.google.android.material.appbar.MaterialToolbar
import com.sza.filler.R

// Ported from FastMediaSorter (ui/common/widget/StandardToolbar.kt, S3248 / S4460; FILLER-0067 here).
// Deliberate difference: places the 8 dp logo-to-title inset on the trailing edge in both LTR and RTL layouts
// so right-to-left locales (ar, ur) also keep an 8 dp gap between the feature glyph and the title.

/**
 * Shared toolbar styled by `Widget.Filler.Toolbar.Flat`, putting `app:stbTitleIcon` beside the title with an
 * 8 dp `toolbar_title_icon_gap` and routing back navigation through `onBackPressedDispatcher`.
 */
class StandardToolbar @JvmOverloads constructor(
    context: Context,
    attrs: AttributeSet? = null,
    defStyleAttr: Int = androidx.appcompat.R.attr.toolbarStyle,
) : MaterialToolbar(context, attrs, defStyleAttr) {

    init {
        context.obtainStyledAttributes(attrs, R.styleable.StandardToolbar, defStyleAttr, 0).use { typedArray ->
            val iconRes = typedArray.getResourceId(R.styleable.StandardToolbar_stbTitleIcon, 0)
            if (iconRes != 0) {
                applyTitleIcon(iconRes, typedArray.getColorStateList(R.styleable.StandardToolbar_stbTitleIconTint))
            }
        }
    }

    fun setUpNavigation(activity: ComponentActivity) {
        setNavigationOnClickListener { activity.onBackPressedDispatcher.onBackPressed() }
    }

    private fun applyTitleIcon(@DrawableRes iconRes: Int, tint: ColorStateList?) {
        val icon = AppCompatResources.getDrawable(context, iconRes)?.mutate() ?: return
        tint?.let { icon.setTintList(it) }
        val gap = resources.getDimensionPixelSize(R.dimen.toolbar_title_icon_gap)
        val isRtl = resources.configuration.layoutDirection == View.LAYOUT_DIRECTION_RTL
        logo = if (isRtl) InsetDrawable(icon, gap, 0, 0, 0) else InsetDrawable(icon, 0, 0, gap, 0)
    }
}
