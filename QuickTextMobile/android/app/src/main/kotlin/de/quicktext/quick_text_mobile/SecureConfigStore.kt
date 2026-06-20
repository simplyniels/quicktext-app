package de.quicktext.quick_text_mobile

import android.content.Context
import android.provider.Settings
import android.util.Base64
import java.security.KeyStore
import javax.crypto.Cipher
import javax.crypto.KeyGenerator
import javax.crypto.SecretKey
import javax.crypto.spec.GCMParameterSpec
import android.security.keystore.KeyGenParameterSpec
import android.security.keystore.KeyProperties

class SecureConfigStore(private val context: Context) {
    private val prefs = context.getSharedPreferences("quick_text_settings", Context.MODE_PRIVATE)
    private val alias = "quick_text_openai_key"

    var language: String
        get() = prefs.getString("language", "de") ?: "de"
        set(value) { prefs.edit().putString("language", value).apply() }

    var workflow: String
        get() = prefs.getString("workflow", "transcription") ?: "transcription"
        set(value) { prefs.edit().putString("workflow", value).apply() }

    var customTerms: String
        get() = prefs.getString("custom_terms", "") ?: ""
        set(value) { prefs.edit().putString("custom_terms", value).apply() }

    fun hasApiKey(): Boolean = prefs.contains("api_key")

    fun saveApiKey(value: String) {
        if (value.isBlank()) {
            prefs.edit().remove("api_key").apply()
            return
        }
        val cipher = Cipher.getInstance("AES/GCM/NoPadding")
        cipher.init(Cipher.ENCRYPT_MODE, getOrCreateKey())
        val encrypted = cipher.doFinal(value.trim().toByteArray(Charsets.UTF_8))
        val payload = Base64.encodeToString(cipher.iv + encrypted, Base64.NO_WRAP)
        prefs.edit().putString("api_key", payload).apply()
    }

    fun readApiKey(): String? = try {
        val encoded = prefs.getString("api_key", null) ?: return null
        val payload = Base64.decode(encoded, Base64.NO_WRAP)
        val cipher = Cipher.getInstance("AES/GCM/NoPadding")
        cipher.init(Cipher.DECRYPT_MODE, getOrCreateKey(), GCMParameterSpec(128, payload.copyOfRange(0, 12)))
        String(cipher.doFinal(payload.copyOfRange(12, payload.size)), Charsets.UTF_8)
    } catch (_: Exception) { null }

    private fun getOrCreateKey(): SecretKey {
        val keyStore = KeyStore.getInstance("AndroidKeyStore").apply { load(null) }
        (keyStore.getKey(alias, null) as? SecretKey)?.let { return it }
        val generator = KeyGenerator.getInstance(KeyProperties.KEY_ALGORITHM_AES, "AndroidKeyStore")
        generator.init(
            KeyGenParameterSpec.Builder(alias, KeyProperties.PURPOSE_ENCRYPT or KeyProperties.PURPOSE_DECRYPT)
                .setBlockModes(KeyProperties.BLOCK_MODE_GCM)
                .setEncryptionPaddings(KeyProperties.ENCRYPTION_PADDING_NONE)
                .build()
        )
        return generator.generateKey()
    }

    fun isAccessibilityEnabled(): Boolean {
        val expected = "${context.packageName}/${QuickTextAccessibilityService::class.java.name}"
        val enabled = Settings.Secure.getString(context.contentResolver, Settings.Secure.ENABLED_ACCESSIBILITY_SERVICES)
        return enabled?.split(':')?.any { it.equals(expected, ignoreCase = true) } == true
    }
}
