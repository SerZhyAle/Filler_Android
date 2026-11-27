package com.sza.filler.ui.help

import android.app.Activity
import android.graphics.drawable.GradientDrawable
import android.graphics.drawable.InsetDrawable
import android.util.TypedValue
import android.view.Gravity
import android.view.KeyEvent
import android.view.View
import android.view.ViewGroup
import android.widget.FrameLayout
import android.widget.LinearLayout
import android.widget.ScrollView
import android.widget.TextView
import androidx.annotation.DrawableRes
import androidx.appcompat.app.AppCompatDialog
import androidx.core.content.ContextCompat
import androidx.core.view.ViewCompat
import androidx.core.view.WindowInsetsCompat
import androidx.core.view.doOnLayout
import androidx.core.view.isVisible
import androidx.core.widget.TextViewCompat
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.LifecycleEventObserver
import androidx.lifecycle.LifecycleOwner
import com.google.android.material.R as MaterialR
import com.google.android.material.card.MaterialCardView
import com.google.android.material.color.MaterialColors
import com.sza.filler.R
import kotlin.math.roundToInt

/**
 * The help layer of a surface (contract `CONTEXT-HELP` rule 6, S0028): a numbered marker over every element the
 * surface shows now, and a list of every entry with its one-line label and, behind a tap or the focus, its fuller text.
 * Read-only: it activates nothing and changes no state. Back, Esc, F1, a tap outside the list (the help button again
 * included, which lies under the layer) all dismiss it, and the window's focus returns where it was.
 *
 * A marker only exists for an element on screen; an element hidden in the current state (Stop outside a run, for
 * example) keeps its entry in the list, whose text says when it appears.
 */
class HelpLayer(
    private val activity: Activity,
    private val entries: List<HelpLayerEntry>,
    private val anchor: String?,
) {
    private val dialog = AppCompatDialog(activity, R.style.Theme_Filler_HelpLayer)
    private val headers = mutableListOf<TextView>()
    private val bodies = mutableListOf<TextView>()
    private lateinit var scroll: ScrollView

    fun show() {
        val root = FrameLayout(activity).apply {
            setBackgroundColor(ContextCompat.getColor(activity, R.color.filler_help_scrim))
            setOnClickListener { dialog.dismiss() }
        }
        val markers = FrameLayout(activity)
        val cardHost = FrameLayout(activity)
        val card = buildCard()
        cardHost.addView(card, FrameLayout.LayoutParams(MATCH, WRAP, Gravity.BOTTOM))
        root.addView(markers, FrameLayout.LayoutParams(MATCH, MATCH))
        root.addView(cardHost, FrameLayout.LayoutParams(MATCH, MATCH))
        ViewCompat.setOnApplyWindowInsetsListener(cardHost) { view, insets ->
            val bars = insets.getInsets(WindowInsetsCompat.Type.systemBars() or WindowInsetsCompat.Type.displayCutout())
            view.setPadding(bars.left, bars.top, bars.right, bars.bottom)
            insets
        }
        dialog.setContentView(root)
        dialog.window?.setLayout(MATCH, MATCH)
        dialog.setOnKeyListener { _, keyCode, event ->
            val closes = keyCode == KeyEvent.KEYCODE_ESCAPE || keyCode == KeyEvent.KEYCODE_F1
            if (closes && event.action == KeyEvent.ACTION_UP) dialog.dismiss()
            closes
        }
        val lifecycle = (activity as? LifecycleOwner)?.lifecycle
        val closeWithScreen = LifecycleEventObserver { _, event ->
            if (event == Lifecycle.Event.ON_DESTROY) dialog.dismiss()
        }
        lifecycle?.addObserver(closeWithScreen)
        dialog.setOnDismissListener { lifecycle?.removeObserver(closeWithScreen) }
        dialog.show()
        root.doOnLayout {
            card.layoutParams = (card.layoutParams as FrameLayout.LayoutParams).apply { height = root.height / 2 }
            placeMarkers(markers)
            openAnchor()
        }
    }

    private fun buildCard(): MaterialCardView {
        val list = LinearLayout(activity).apply {
            orientation = LinearLayout.VERTICAL
            setPadding(dp(CARD_PADDING_DP), dp(CARD_PADDING_DP), dp(CARD_PADDING_DP), dp(CARD_PADDING_DP))
        }
        list.addView(
            TextView(activity).apply {
                text = activity.getString(R.string.filler_help_heading)
                setTextAppearance(themeRes(MaterialR.attr.textAppearanceTitleMedium))
                ViewCompat.setAccessibilityHeading(this, true)
                // The help carries the product's mark: the inherited Filler block of the toolbar (FILLER-0059).
                showGlyph(this, R.drawable.ic_storage)
            },
        )
        entries.forEachIndexed { index, entry -> addEntry(list, index, entry) }
        scroll = ScrollView(activity).apply { addView(list) }
        return MaterialCardView(activity).apply {
            isClickable = true
            addView(scroll, FrameLayout.LayoutParams(MATCH, MATCH))
        }
    }

    private fun addEntry(list: LinearLayout, index: Int, entry: HelpLayerEntry) {
        val header = TextView(activity).apply {
            text = activity.getString(R.string.filler_help_entry, index + 1, activity.getString(entry.label))
            setTextAppearance(themeRes(MaterialR.attr.textAppearanceTitleSmall))
            minHeight = dp(TARGET_DP)
            gravity = Gravity.CENTER_VERTICAL or Gravity.START
            isFocusable = true
            isClickable = true
            setBackgroundResource(themeRes(android.R.attr.selectableItemBackground))
            setOnClickListener { expand(index, toggle = true) }
            setOnFocusChangeListener { _, hasFocus -> if (hasFocus) expand(index, toggle = false) }
            entry.glyph?.let { showGlyph(this, it) }
        }
        val body = TextView(activity).apply {
            text = activity.getString(entry.text)
            setTextAppearance(themeRes(MaterialR.attr.textAppearanceBodyMedium))
            setPadding(0, 0, 0, dp(BODY_GAP_DP))
            isVisible = false
        }
        headers += header
        bodies += body
        list.addView(header, LinearLayout.LayoutParams(MATCH, WRAP))
        list.addView(body, LinearLayout.LayoutParams(MATCH, WRAP))
    }

    /** Opens [index]'s fuller text and closes the others; a tap on the open entry closes it again. */
    private fun expand(index: Int, toggle: Boolean) {
        val open = !(toggle && bodies[index].isVisible)
        bodies.forEachIndexed { i, body -> body.isVisible = open && i == index }
        if (open) scroll.post { scroll.smoothScrollTo(0, headers[index].top) }
    }

    private fun openAnchor() {
        val index = entries.indexOfFirst { it.anchor == anchor }
        if (index < 0) return
        expand(index, toggle = false)
        headers[index].requestFocus()
    }

    private fun placeMarkers(layer: FrameLayout) {
        val origin = IntArray(2).also(layer::getLocationOnScreen)
        val rtl = layer.layoutDirection == View.LAYOUT_DIRECTION_RTL
        val size = dp(TARGET_DP)
        entries.forEachIndexed { index, entry ->
            val target = entry.viewId?.let { activity.findViewById<View>(it) }
            if (target == null || !target.isShown || target.width == 0) return@forEachIndexed
            val at = IntArray(2).also(target::getLocationOnScreen)
            val left = at[0] - origin[0]
            val right = left + target.width
            val top = at[1] - origin[1]
            val (x, y) = if (isInToolbar(target)) {
                (left + (target.width - size) / 2).coerceIn(0, (layer.width - size).coerceAtLeast(0)) to
                    (top + target.height - dp(MARKER_INSET_DP)).coerceIn(0, (layer.height - size).coerceAtLeast(0))
            } else {
                val markerX = when {
                    rtl && left - size >= 0 -> left - size
                    rtl -> left
                    right + size <= layer.width -> right
                    else -> right - size
                }
                val markerY = (top + (target.height - size) / 2).coerceIn(0, (layer.height - size).coerceAtLeast(0))
                markerX to markerY
            }
            layer.addView(marker(index, entry), FrameLayout.LayoutParams(size, size).apply { leftMargin = x; topMargin = y })
        }
    }

    private fun isInToolbar(view: View): Boolean {
        var parent = view.parent
        while (parent is View) {
            if (parent is androidx.appcompat.widget.Toolbar) return true
            parent = parent.parent
        }
        return false
    }

    private fun marker(index: Int, entry: HelpLayerEntry): TextView = TextView(activity).apply {
        val label = activity.getString(entry.label)
        text = (index + 1).toString()
        contentDescription = activity.getString(R.string.filler_help_entry, index + 1, label)
        gravity = Gravity.CENTER
        setTextAppearance(themeRes(MaterialR.attr.textAppearanceLabelLarge))
        setTextColor(MaterialColors.getColor(this, MaterialR.attr.colorOnPrimary))
        val fill = MaterialColors.getColor(this, androidx.appcompat.R.attr.colorPrimary)
        val dot = GradientDrawable().apply {
            shape = GradientDrawable.OVAL
            setColor(fill)
        }
        background = InsetDrawable(dot, dp(MARKER_INSET_DP))
        isFocusable = true
        isClickable = true
        setOnClickListener {
            expand(index, toggle = false)
            headers[index].requestFocus()
        }
        setOnFocusChangeListener { _, hasFocus -> if (hasFocus) expand(index, toggle = false) }
    }

    /**
     * Draws [glyph] before the text of [view] in the text's own ink: the control's glyph beside its name (`ICON-SET`
     * rule 8, FILLER-0059). Decorative - the text already carries the name the accessibility service reads.
     */
    private fun showGlyph(view: TextView, @DrawableRes glyph: Int) {
        TextViewCompat.setCompoundDrawablesRelativeWithIntrinsicBounds(view, glyph, 0, 0, 0)
        TextViewCompat.setCompoundDrawableTintList(view, view.textColors)
        view.compoundDrawablePadding = dp(GLYPH_GAP_DP)
    }

    private fun themeRes(attr: Int): Int {
        val value = TypedValue()
        activity.theme.resolveAttribute(attr, value, true)
        return value.resourceId
    }

    private fun dp(value: Int): Int = (value * activity.resources.displayMetrics.density).roundToInt()

    private companion object {
        const val MATCH = ViewGroup.LayoutParams.MATCH_PARENT
        const val WRAP = ViewGroup.LayoutParams.WRAP_CONTENT
        const val TARGET_DP = 48
        const val MARKER_INSET_DP = 8
        const val CARD_PADDING_DP = 16
        const val BODY_GAP_DP = 8
        const val GLYPH_GAP_DP = 12
    }
}
