package de.quicktext.quick_text_mobile

import android.animation.ValueAnimator
import android.content.Context
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.util.AttributeSet
import android.view.View
import android.view.animation.LinearInterpolator
import kotlin.math.PI
import kotlin.math.sin

class WaveformView @JvmOverloads constructor(
    context: Context,
    attrs: AttributeSet? = null,
) : View(context, attrs) {
    private val paint = Paint(Paint.ANTI_ALIAS_FLAG).apply { color = Color.WHITE }
    private var phase = 0f
    private var targetAmplitude = 0.25f
    private var displayedAmplitude = 0.25f
    private val animator = ValueAnimator.ofFloat(0f, (2 * PI).toFloat()).apply {
        duration = 900
        repeatCount = ValueAnimator.INFINITE
        interpolator = LinearInterpolator()
        addUpdateListener {
            phase = it.animatedValue as Float
            displayedAmplitude += (targetAmplitude - displayedAmplitude) * 0.22f
            invalidate()
        }
    }

    fun setAmplitude(value: Float) {
        targetAmplitude = value.coerceIn(0.12f, 1f)
    }

    override fun onAttachedToWindow() {
        super.onAttachedToWindow()
        animator.start()
    }

    override fun onDetachedFromWindow() {
        animator.cancel()
        super.onDetachedFromWindow()
    }

    override fun onDraw(canvas: Canvas) {
        super.onDraw(canvas)
        val barWidth = width / 11f
        val gap = barWidth
        val centerY = height / 2f
        paint.strokeWidth = barWidth
        paint.strokeCap = Paint.Cap.ROUND
        repeat(5) { index ->
            val wave = (sin(phase + index * 0.9f) + 1f) / 2f
            val heightFactor = 0.22f + displayedAmplitude * (0.35f + wave * 0.43f)
            val halfHeight = height * heightFactor / 2f
            val x = barWidth + index * (barWidth + gap)
            canvas.drawLine(x, centerY - halfHeight, x, centerY + halfHeight, paint)
        }
    }
}
