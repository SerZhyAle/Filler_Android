package com.sza.filler.ui.common.widget

import android.content.Context
import android.util.AttributeSet
import android.view.View
import android.view.ViewGroup
import com.sza.filler.R

/**
 * Simple RTL-aware wrapping horizontal container for content-sized command buttons (FILLER-0067).
 * Places buttons side by side with an 8 dp gap when they fit and wraps cleanly onto the next row
 * on narrow 320 dp screens or enlarged font scales (UI-SIZING 1.2) so no button caption clips.
 */
class FlowRowLayout @JvmOverloads constructor(
    context: Context,
    attrs: AttributeSet? = null,
    defStyleAttr: Int = 0,
) : ViewGroup(context, attrs, defStyleAttr) {

    private val horizontalGap = resources.getDimensionPixelSize(R.dimen.filler_spacing_8)
    private val verticalGap = resources.getDimensionPixelSize(R.dimen.filler_spacing_4)

    override fun onMeasure(widthMeasureSpec: Int, heightMeasureSpec: Int) {
        val widthMode = MeasureSpec.getMode(widthMeasureSpec)
        val widthLimit = if (widthMode == MeasureSpec.UNSPECIFIED) {
            Int.MAX_VALUE
        } else {
            (MeasureSpec.getSize(widthMeasureSpec) - paddingLeft - paddingRight).coerceAtLeast(0)
        }
        val childWidthSpec = if (widthMode == MeasureSpec.UNSPECIFIED) {
            MeasureSpec.makeMeasureSpec(0, MeasureSpec.UNSPECIFIED)
        } else {
            MeasureSpec.makeMeasureSpec(widthLimit, MeasureSpec.AT_MOST)
        }
        val childHeightSpec = MeasureSpec.makeMeasureSpec(0, MeasureSpec.UNSPECIFIED)

        var lineWidth = 0
        var lineHeight = 0
        var maxWidth = 0
        var totalHeight = 0

        for (i in 0 until childCount) {
            val child = getChildAt(i)
            if (child.visibility == View.GONE) continue
            child.measure(childWidthSpec, childHeightSpec)
            val cw = child.measuredWidth
            val ch = child.measuredHeight
            val needed = if (lineWidth == 0) cw else lineWidth + horizontalGap + cw
            if (lineWidth > 0 && needed > widthLimit) {
                maxWidth = maxOf(maxWidth, lineWidth)
                totalHeight += lineHeight + verticalGap
                lineWidth = cw
                lineHeight = ch
            } else {
                lineWidth = needed
                lineHeight = maxOf(lineHeight, ch)
            }
        }
        maxWidth = maxOf(maxWidth, lineWidth)
        totalHeight += lineHeight

        val measuredW = resolveSize(maxWidth + paddingLeft + paddingRight, widthMeasureSpec)
        val measuredH = resolveSize(totalHeight + paddingTop + paddingBottom, heightMeasureSpec)
        setMeasuredDimension(measuredW, measuredH)
    }

    override fun onLayout(changed: Boolean, left: Int, top: Int, right: Int, bottom: Int) {
        val contentWidth = (right - left - paddingLeft - paddingRight).coerceAtLeast(0)
        val isRtl = layoutDirection == View.LAYOUT_DIRECTION_RTL
        var cursorX = 0
        var cursorY = paddingTop
        var lineHeight = 0

        for (i in 0 until childCount) {
            val child = getChildAt(i)
            if (child.visibility == View.GONE) continue
            val cw = child.measuredWidth
            val ch = child.measuredHeight
            val needed = if (cursorX == 0) cw else cursorX + horizontalGap + cw
            if (cursorX > 0 && needed > contentWidth) {
                cursorY += lineHeight + verticalGap
                cursorX = 0
                lineHeight = 0
            }
            val startX = if (cursorX == 0) 0 else cursorX + horizontalGap
            val childLeft = if (isRtl) {
                (right - left) - paddingRight - startX - cw
            } else {
                paddingLeft + startX
            }
            child.layout(childLeft, cursorY, childLeft + cw, cursorY + ch)
            cursorX = startX + cw
            lineHeight = maxOf(lineHeight, ch)
        }
    }
}
