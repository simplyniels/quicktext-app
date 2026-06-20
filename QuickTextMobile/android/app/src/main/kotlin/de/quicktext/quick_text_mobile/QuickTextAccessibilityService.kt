package de.quicktext.quick_text_mobile

import android.animation.ObjectAnimator
import android.animation.ValueAnimator
import android.Manifest
import android.accessibilityservice.AccessibilityService
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.ClipData
import android.content.ClipboardManager
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.content.pm.ServiceInfo
import android.graphics.Color
import android.graphics.Rect
import android.graphics.drawable.GradientDrawable
import android.media.MediaRecorder
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.os.SystemClock
import android.view.Gravity
import android.view.View
import android.view.WindowManager
import android.view.accessibility.AccessibilityEvent
import android.view.accessibility.AccessibilityNodeInfo
import android.view.accessibility.AccessibilityWindowInfo
import android.widget.ImageButton
import android.widget.LinearLayout
import android.widget.TextView
import android.widget.Toast
import androidx.core.app.NotificationCompat
import androidx.core.content.ContextCompat
import java.io.File
import java.util.concurrent.Executors
import kotlin.math.max

class QuickTextAccessibilityService : AccessibilityService() {
    private val main = Handler(Looper.getMainLooper())
    private val executor = Executors.newSingleThreadExecutor()
    private lateinit var windowManager: WindowManager
    private var overlay: View? = null
    private var recorder: MediaRecorder? = null
    private var recordingFile: File? = null
    private var recordingStartedAt = 0L
    private var state = State.IDLE
    private var lastEditableFocusAt = 0L
    private var timer: TextView? = null
    private var pulseAnimator: ObjectAnimator? = null
    private val timerTick = object : Runnable {
        override fun run() {
            if (state != State.RECORDING) return
            val seconds = (SystemClock.elapsedRealtime() - recordingStartedAt) / 1000
            timer?.text = "%d:%02d".format(seconds / 60, seconds % 60)
            if (seconds >= 60) stopAndTranscribe() else main.postDelayed(this, 250)
        }
    }

    override fun onServiceConnected() {
        super.onServiceConnected()
        windowManager = getSystemService(WINDOW_SERVICE) as WindowManager
        createNotificationChannel()
    }

    override fun onAccessibilityEvent(event: AccessibilityEvent?) {
        if (event == null || state != State.IDLE) return
        if (event.packageName?.toString() == packageName) {
            hideOverlay()
            return
        }
        val focused = rootInActiveWindow?.findFocus(AccessibilityNodeInfo.FOCUS_INPUT)
        val keyboardVisible = windows.any { it.type == AccessibilityWindowInfo.TYPE_INPUT_METHOD }
        val valid = focused?.isEditable == true && !isSensitive(focused) && keyboardVisible
        if (valid) {
            lastEditableFocusAt = SystemClock.elapsedRealtime()
            showIdleBubble()
        } else if (SystemClock.elapsedRealtime() - lastEditableFocusAt > 700) {
            hideOverlay()
        }
    }

    override fun onInterrupt() {
        cancelRecording()
        hideOverlay()
    }

    override fun onDestroy() {
        cancelRecording()
        hideOverlay()
        executor.shutdownNow()
        super.onDestroy()
    }

    private fun showIdleBubble() {
        if (overlay != null) return
        val button = ImageButton(this).apply {
            setImageResource(android.R.drawable.ic_btn_speak_now)
            setColorFilter(Color.WHITE)
            setPadding(dp(17), dp(17), dp(17), dp(17))
            elevation = dp(12).toFloat()
            contentDescription = "Quick Text starten"
            background = rounded(0xFF6D5DFCL.toInt(), 32)
            setOnClickListener { startRecording() }
        }
        replaceOverlay(button, 64, 64)
    }

    private fun showRecordingPill() {
        val pill = LinearLayout(this).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER_VERTICAL
            setPadding(dp(18), 0, dp(8), 0)
            background = rounded(0xFF17151FL.toInt(), 32)
            elevation = dp(12).toFloat()
        }
        val dot = TextView(this).apply {
            text = "●"
            textSize = 20f
            setTextColor(0xFFFF5B6E.toInt())
            gravity = Gravity.CENTER
        }
        pulseAnimator = ObjectAnimator.ofFloat(dot, View.ALPHA, 1f, 0.22f).apply {
            duration = 520
            repeatCount = ValueAnimator.INFINITE
            repeatMode = ValueAnimator.REVERSE
            start()
        }
        timer = TextView(this).apply {
            text = "0:00"
            textSize = 16f
            setTextColor(Color.WHITE)
            setPadding(dp(10), 0, dp(18), 0)
        }
        val stop = TextView(this).apply {
            text = "■"
            textSize = 18f
            setTextColor(Color.WHITE)
            gravity = Gravity.CENTER
            contentDescription = "Aufnahme beenden"
            background = rounded(0xFFFF4F67.toInt(), 26)
            setOnClickListener { stopAndTranscribe() }
        }
        pill.addView(dot, LinearLayout.LayoutParams(dp(32), dp(56)))
        pill.addView(timer, LinearLayout.LayoutParams(0, dp(56), 1f))
        pill.addView(stop, LinearLayout.LayoutParams(dp(52), dp(52)))
        replaceOverlay(pill, 210, 64)
    }

    private fun showProcessingPill() {
        val textView = TextView(this).apply {
            text = "  ✦  Transkribiere …  "
            textSize = 16f
            setTextColor(Color.WHITE)
            gravity = Gravity.CENTER
            background = rounded(0xFF17151FL.toInt(), 32)
            elevation = dp(12).toFloat()
        }
        replaceOverlay(textView, 190, 64)
    }

    private fun startRecording() {
        if (ContextCompat.checkSelfPermission(this, Manifest.permission.RECORD_AUDIO) != PackageManager.PERMISSION_GRANTED) {
            Toast.makeText(this, "Bitte Mikrofonzugriff in Quick Text erlauben.", Toast.LENGTH_LONG).show()
            openApp()
            return
        }
        val key = SecureConfigStore(this).readApiKey()
        if (key.isNullOrBlank()) {
            Toast.makeText(this, "Bitte zuerst den OpenAI API-Key in Quick Text speichern.", Toast.LENGTH_LONG).show()
            openApp()
            return
        }
        try {
            startRecordingForeground()
            recordingFile = File(cacheDir, "quick-text-${System.currentTimeMillis()}.m4a")
            recorder = MediaRecorder(this).apply {
                setAudioSource(MediaRecorder.AudioSource.MIC)
                setOutputFormat(MediaRecorder.OutputFormat.MPEG_4)
                setAudioEncoder(MediaRecorder.AudioEncoder.AAC)
                setAudioEncodingBitRate(64_000)
                setAudioSamplingRate(44_100)
                setOutputFile(recordingFile!!.absolutePath)
                prepare()
                start()
            }
            state = State.RECORDING
            recordingStartedAt = SystemClock.elapsedRealtime()
            showRecordingPill()
            main.post(timerTick)
        } catch (error: Exception) {
            cancelRecording()
            Toast.makeText(this, "Aufnahme konnte nicht gestartet werden.", Toast.LENGTH_LONG).show()
        }
    }

    private fun stopAndTranscribe() {
        if (state != State.RECORDING) return
        state = State.PROCESSING
        main.removeCallbacks(timerTick)
        try { recorder?.stop() } catch (_: Exception) { }
        recorder?.release()
        recorder = null
        stopForeground(STOP_FOREGROUND_REMOVE)
        showProcessingPill()
        val file = recordingFile ?: return finishWithError("Aufnahme fehlt")
        val store = SecureConfigStore(this)
        val key = store.readApiKey() ?: return finishWithError("API-Key fehlt")
        executor.execute {
            try {
                val transcript = OpenAiClient.transcribe(file, key, store.language, store.customTerms)
                val result = OpenAiClient.rewrite(transcript, key, store.workflow)
                main.post { insertOrCopy(result) }
            } catch (error: Exception) {
                main.post { finishWithError(error.message ?: "Transkription fehlgeschlagen") }
            } finally {
                file.delete()
            }
        }
    }

    private fun insertOrCopy(text: String) {
        val clipboard = getSystemService(Context.CLIPBOARD_SERVICE) as ClipboardManager
        clipboard.setPrimaryClip(ClipData.newPlainText("Quick Text", text))
        val focused = rootInActiveWindow?.findFocus(AccessibilityNodeInfo.FOCUS_INPUT)
        var inserted = false
        if (focused?.isEditable == true && !isSensitive(focused)) {
            inserted = focused.performAction(AccessibilityNodeInfo.ACTION_PASTE)
            if (!inserted) {
                val old = focused.text?.toString().orEmpty()
                val start = focused.textSelectionStart.coerceIn(0, old.length)
                val end = max(start, focused.textSelectionEnd.coerceIn(0, old.length))
                val replacement = old.substring(0, start) + text + old.substring(end)
                val args = Bundle().apply { putCharSequence(AccessibilityNodeInfo.ACTION_ARGUMENT_SET_TEXT_CHARSEQUENCE, replacement) }
                inserted = focused.performAction(AccessibilityNodeInfo.ACTION_SET_TEXT, args)
            }
        }
        Toast.makeText(this, if (inserted) "Text eingefügt" else "In Zwischenablage kopiert", Toast.LENGTH_SHORT).show()
        state = State.IDLE
        hideOverlay()
    }

    private fun finishWithError(message: String) {
        recordingFile?.delete()
        recordingFile = null
        state = State.IDLE
        stopForeground(STOP_FOREGROUND_REMOVE)
        Toast.makeText(this, message.take(160), Toast.LENGTH_LONG).show()
        hideOverlay()
    }

    private fun cancelRecording() {
        main.removeCallbacks(timerTick)
        try { recorder?.stop() } catch (_: Exception) { }
        recorder?.release()
        recorder = null
        recordingFile?.delete()
        recordingFile = null
        state = State.IDLE
        stopForeground(STOP_FOREGROUND_REMOVE)
    }

    private fun replaceOverlay(view: View, widthDp: Int, heightDp: Int) {
        hideOverlay()
        overlay = view
        val params = WindowManager.LayoutParams(
            dp(widthDp), dp(heightDp),
            WindowManager.LayoutParams.TYPE_ACCESSIBILITY_OVERLAY,
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or WindowManager.LayoutParams.FLAG_NOT_TOUCH_MODAL,
            android.graphics.PixelFormat.TRANSLUCENT,
        ).apply {
            gravity = Gravity.BOTTOM or Gravity.END
            x = dp(18)
            y = keyboardBottomOffset()
        }
        windowManager.addView(view, params)
    }

    private fun keyboardBottomOffset(): Int {
        val keyboard = windows.firstOrNull { it.type == AccessibilityWindowInfo.TYPE_INPUT_METHOD } ?: return dp(92)
        val bounds = Rect()
        keyboard.getBoundsInScreen(bounds)
        val screenHeight = resources.displayMetrics.heightPixels
        return (screenHeight - bounds.top + dp(14)).coerceAtLeast(dp(92))
    }

    private fun hideOverlay() {
        pulseAnimator?.cancel()
        pulseAnimator = null
        overlay?.let { runCatching { windowManager.removeView(it) } }
        overlay = null
        timer = null
    }

    private fun isSensitive(node: AccessibilityNodeInfo): Boolean {
        if (node.isPassword) return true
        val type = node.inputType
        val variation = type and 0x00000ff0
        return variation == 0x80 || variation == 0x90 || variation == 0xe0
    }

    private fun rounded(color: Int, radiusDp: Int) = GradientDrawable().apply {
        setColor(color)
        cornerRadius = dp(radiusDp).toFloat()
    }

    private fun startRecordingForeground() {
        val intent = Intent(this, MainActivity::class.java)
        val pending = PendingIntent.getActivity(this, 0, intent, PendingIntent.FLAG_IMMUTABLE)
        val notification = NotificationCompat.Builder(this, "quick_text_recording")
            .setSmallIcon(android.R.drawable.ic_btn_speak_now)
            .setContentTitle("Quick Text nimmt auf")
            .setContentText("Tippe auf die rote Taste, um zu transkribieren.")
            .setContentIntent(pending)
            .setOngoing(true)
            .build()
        startForeground(704, notification, ServiceInfo.FOREGROUND_SERVICE_TYPE_MICROPHONE)
    }

    private fun createNotificationChannel() {
        val manager = getSystemService(NotificationManager::class.java)
        manager.createNotificationChannel(NotificationChannel("quick_text_recording", "Sprachaufnahme", NotificationManager.IMPORTANCE_LOW))
    }

    private fun openApp() {
        val intent = packageManager.getLaunchIntentForPackage(packageName)?.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        if (intent != null) startActivity(intent)
    }

    private fun dp(value: Int) = (value * resources.displayMetrics.density).toInt()
    private enum class State { IDLE, RECORDING, PROCESSING }
}
