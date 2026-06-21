package de.quicktext.quick_text_mobile

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
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.os.SystemClock
import android.view.Gravity
import android.view.MotionEvent
import android.view.View
import android.view.ViewConfiguration
import android.view.WindowInsets
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
import kotlin.math.abs
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
    private var lastEditorSeenAt = 0L
    private var timer: TextView? = null
    private var waveform: WaveformView? = null
    private var overlayParams: WindowManager.LayoutParams? = null
    private var anchorX = -1
    private var anchorY = -1
    private val positionPrefs by lazy { getSharedPreferences("quick_text_overlay", Context.MODE_PRIVATE) }
    private val hideOverlayDelayed: Runnable = object : Runnable {
        override fun run() {
            if (state != State.IDLE) return
            val activePackage = rootInActiveWindow?.packageName?.toString()
            when {
                activePackage == packageName -> hideOverlay()
                hasValidInputTarget() -> {
                    lastEditorSeenAt = SystemClock.elapsedRealtime()
                    showIdleBubble()
                }
                overlay != null && isKeyboardVisible() &&
                    SystemClock.elapsedRealtime() - lastEditorSeenAt < 30_000 ->
                    main.postDelayed(this, 1_500)
                else -> hideOverlay()
            }
        }
    }
    private val timerTick = object : Runnable {
        override fun run() {
            if (state != State.RECORDING) return
            val seconds = (SystemClock.elapsedRealtime() - recordingStartedAt) / 1000
            timer?.text = "%d:%02d".format(seconds / 60, seconds % 60)
            val amplitude = runCatching { (recorder?.maxAmplitude ?: 0) / 32_767f }.getOrDefault(0f)
            waveform?.setAmplitude(amplitude)
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
        if (isValidEditor(event.source) || hasValidInputTarget()) {
            lastEditorSeenAt = SystemClock.elapsedRealtime()
            main.removeCallbacks(hideOverlayDelayed)
            showIdleBubble()
        } else {
            main.removeCallbacks(hideOverlayDelayed)
            main.postDelayed(hideOverlayDelayed, 1_200)
        }
    }

    override fun onInterrupt() {
        main.removeCallbacks(hideOverlayDelayed)
        cancelRecording()
        hideOverlay()
    }

    override fun onDestroy() {
        main.removeCallbacks(hideOverlayDelayed)
        cancelRecording()
        hideOverlay()
        executor.shutdownNow()
        super.onDestroy()
    }

    private fun showIdleBubble() {
        if (overlay != null) return
        val button = ImageButton(this).apply {
            setImageResource(R.drawable.ic_quick_text_mark)
            setPadding(dp(13), dp(13), dp(13), dp(13))
            elevation = dp(12).toFloat()
            contentDescription = "Quick Text starten"
            background = rounded(0xFF1677FF.toInt(), 27)
            setOnClickListener { startRecording() }
        }
        addDragBehavior(button)
        replaceOverlay(button, 54, 54)
    }

    private fun showRecordingPill() {
        val pill = LinearLayout(this).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER_VERTICAL
            setPadding(dp(18), 0, dp(8), 0)
            background = rounded(0xFF17151FL.toInt(), 32)
            elevation = dp(12).toFloat()
        }
        waveform = WaveformView(this)
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
        pill.addView(waveform, LinearLayout.LayoutParams(dp(52), dp(48)))
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
        val minimumY = keyboardBottomOffset() + dp(88)
        val maximumY = resources.displayMetrics.heightPixels - dp(heightDp + 24)
        if (anchorX < 0) anchorX = positionPrefs.getInt("x", dp(16))
        if (anchorY < 0) anchorY = positionPrefs.getInt("y", minimumY + dp(32))
        anchorX = anchorX.coerceIn(0, (resources.displayMetrics.widthPixels - dp(widthDp)).coerceAtLeast(0))
        anchorY = anchorY.coerceIn(minimumY, maximumY.coerceAtLeast(minimumY))
        val params = WindowManager.LayoutParams(
            dp(widthDp), dp(heightDp),
            WindowManager.LayoutParams.TYPE_ACCESSIBILITY_OVERLAY,
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or WindowManager.LayoutParams.FLAG_NOT_TOUCH_MODAL,
            android.graphics.PixelFormat.TRANSLUCENT,
        ).apply {
            gravity = Gravity.BOTTOM or Gravity.END
            x = anchorX
            y = anchorY
        }
        overlayParams = params
        windowManager.addView(view, params)
    }

    private fun addDragBehavior(view: View) {
        val touchSlop = ViewConfiguration.get(this).scaledTouchSlop
        var downX = 0f
        var downY = 0f
        var startX = 0
        var startY = 0
        var dragged = false
        view.setOnTouchListener { target, event ->
            val params = overlayParams ?: return@setOnTouchListener false
            when (event.actionMasked) {
                MotionEvent.ACTION_DOWN -> {
                    main.removeCallbacks(hideOverlayDelayed)
                    downX = event.rawX
                    downY = event.rawY
                    startX = params.x
                    startY = params.y
                    dragged = false
                    true
                }
                MotionEvent.ACTION_MOVE -> {
                    val deltaX = event.rawX - downX
                    val deltaY = event.rawY - downY
                    if (abs(deltaX) > touchSlop || abs(deltaY) > touchSlop) dragged = true
                    val minY = keyboardBottomOffset() + dp(72)
                    val maxX = (resources.displayMetrics.widthPixels - target.width).coerceAtLeast(0)
                    val maxY = (resources.displayMetrics.heightPixels - target.height - dp(24)).coerceAtLeast(minY)
                    params.x = (startX - deltaX.toInt()).coerceIn(0, maxX)
                    params.y = (startY - deltaY.toInt()).coerceIn(minY, maxY)
                    anchorX = params.x
                    anchorY = params.y
                    runCatching { windowManager.updateViewLayout(target, params) }
                    true
                }
                MotionEvent.ACTION_UP -> {
                    if (dragged) {
                        positionPrefs.edit().putInt("x", anchorX).putInt("y", anchorY).apply()
                    } else {
                        target.performClick()
                    }
                    true
                }
                MotionEvent.ACTION_CANCEL -> true
                else -> false
            }
        }
    }

    private fun keyboardBottomOffset(): Int {
        val keyboard = windows.firstOrNull { it.type == AccessibilityWindowInfo.TYPE_INPUT_METHOD } ?: return dp(92)
        val bounds = Rect()
        keyboard.getBoundsInScreen(bounds)
        val screenHeight = resources.displayMetrics.heightPixels
        return (screenHeight - bounds.top + dp(14)).coerceAtLeast(dp(92))
    }

    private fun hideOverlay() {
        overlay?.let { runCatching { windowManager.removeView(it) } }
        overlay = null
        overlayParams = null
        timer = null
        waveform = null
    }

    private fun hasValidInputTarget(): Boolean {
        val root = rootInActiveWindow ?: return false
        root.findFocus(AccessibilityNodeInfo.FOCUS_INPUT)?.let {
            if (isValidEditor(it)) return true
        }
        val queue = ArrayDeque<AccessibilityNodeInfo>()
        queue.add(root)
        var inspected = 0
        while (queue.isNotEmpty() && inspected < 120) {
            val node = queue.removeFirst()
            inspected++
            if ((node.isFocused || node.isAccessibilityFocused) && isValidEditor(node)) return true
            repeat(node.childCount) { index -> node.getChild(index)?.let(queue::addLast) }
        }
        return false
    }

    private fun isValidEditor(node: AccessibilityNodeInfo?): Boolean {
        if (node == null || node.packageName?.toString() == packageName || isSensitive(node)) return false
        val canSetText = node.actionList.any { it.id == AccessibilityNodeInfo.ACTION_SET_TEXT }
        val editTextClass = node.className?.toString()?.contains("EditText", ignoreCase = true) == true
        return node.isEditable || canSetText || editTextClass
    }

    private fun isKeyboardVisible(): Boolean {
        if (windows.any { it.type == AccessibilityWindowInfo.TYPE_INPUT_METHOD }) return true
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            windowManager.currentWindowMetrics.windowInsets.isVisible(WindowInsets.Type.ime())
        } else false
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
