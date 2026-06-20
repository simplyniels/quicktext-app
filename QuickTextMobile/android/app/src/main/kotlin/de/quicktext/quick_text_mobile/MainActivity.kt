package de.quicktext.quick_text_mobile

import android.Manifest
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import android.os.Bundle
import android.provider.Settings
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val channelName = "de.quicktext.mobile/system"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName).setMethodCallHandler { call, result ->
            val store = SecureConfigStore(this)
            when (call.method) {
                "getStatus" -> result.success(mapOf(
                    "microphone" to hasPermission(Manifest.permission.RECORD_AUDIO),
                    "accessibility" to store.isAccessibilityEnabled(),
                    "apiKey" to store.hasApiKey(),
                    "language" to store.language,
                    "workflow" to store.workflow,
                    "customTerms" to store.customTerms,
                ))
                "saveSettings" -> {
                    call.argument<String>("apiKey")?.takeIf { it.isNotBlank() }?.let(store::saveApiKey)
                    call.argument<String>("language")?.let { store.language = it }
                    call.argument<String>("workflow")?.let { store.workflow = it }
                    call.argument<String>("customTerms")?.let { store.customTerms = it }
                    result.success(true)
                }
                "requestPermissions" -> {
                    val permissions = buildList {
                        if (!hasPermission(Manifest.permission.RECORD_AUDIO)) add(Manifest.permission.RECORD_AUDIO)
                        if (Build.VERSION.SDK_INT >= 33 && !hasPermission(Manifest.permission.POST_NOTIFICATIONS)) add(Manifest.permission.POST_NOTIFICATIONS)
                    }
                    if (permissions.isNotEmpty()) ActivityCompat.requestPermissions(this, permissions.toTypedArray(), 41)
                    result.success(true)
                }
                "openAccessibility" -> {
                    startActivity(Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS))
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun hasPermission(permission: String) =
        ContextCompat.checkSelfPermission(this, permission) == PackageManager.PERMISSION_GRANTED
}
