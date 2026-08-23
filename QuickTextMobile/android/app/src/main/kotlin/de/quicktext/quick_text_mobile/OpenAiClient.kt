package de.quicktext.quick_text_mobile

import org.json.JSONArray
import org.json.JSONObject
import java.io.File
import java.net.HttpURLConnection
import java.net.URL
import java.util.UUID

object OpenAiClient {
    fun transcribe(file: File, key: String, language: String, terms: String): String {
        val boundary = "QuickText-${UUID.randomUUID()}"
        val connection = URL("https://api.openai.com/v1/audio/transcriptions").openConnection() as HttpURLConnection
        connection.requestMethod = "POST"
        connection.connectTimeout = 20_000
        connection.readTimeout = 90_000
        connection.doOutput = true
        connection.setRequestProperty("Authorization", "Bearer $key")
        connection.setRequestProperty("Content-Type", "multipart/form-data; boundary=$boundary")
        connection.outputStream.buffered().use { output ->
            fun field(name: String, value: String) {
                output.write("--$boundary\r\nContent-Disposition: form-data; name=\"$name\"\r\n\r\n$value\r\n".toByteArray())
            }
            field("model", "gpt-transcribe")
            if (language.matches(Regex("[a-z]{2}"))) field("languages[]", language)
            transcriptionKeywords(terms).forEach { field("keywords[]", it) }
            output.write("--$boundary\r\nContent-Disposition: form-data; name=\"file\"; filename=\"recording.m4a\"\r\nContent-Type: audio/mp4\r\n\r\n".toByteArray())
            file.inputStream().use { it.copyTo(output) }
            output.write("\r\n--$boundary--\r\n".toByteArray())
        }
        return parseResponse(connection, "text")
    }

    private fun transcriptionKeywords(terms: String): List<String> = terms
        .split(',', ';', '\n', '\r')
        .map(String::trim)
        .filter { it.isNotEmpty() && '<' !in it && '>' !in it }
        .distinct()

    fun rewrite(text: String, key: String, workflow: String): String {
        if (workflow == "transcription") return text
        val (model, prompt) = when (workflow) {
            "improve" -> "gpt-4o-mini" to "Du bist ein Lektor. Entferne Füllwörter, korrigiere Grammatik und Zeichensetzung und verbessere den Lesefluss, ohne Bedeutung oder Ton zu verändern. Gib nur den fertigen Text zurück."
            "calm" -> "gpt-4o" to "Formuliere den gesprochenen Text als ruhige, respektvolle und konstruktive Nachricht. Erhalte Anliegen und Fakten, entferne Beleidigungen und Eskalation. Gib nur die fertige Nachricht zurück."
            "emoji" -> "gpt-4o-mini" to "Gib das Transkript möglichst originalgetreu zurück, korrigiere offensichtliche Fehler und füge etwa alle ein bis zwei Sätze passende Emojis ein. Gib nur den fertigen Text zurück."
            else -> return text
        }
        val body = JSONObject()
            .put("model", model)
            .put("messages", JSONArray()
                .put(JSONObject().put("role", "system").put("content", prompt))
                .put(JSONObject().put("role", "user").put("content", text)))
            .toString()
        val connection = URL("https://api.openai.com/v1/chat/completions").openConnection() as HttpURLConnection
        connection.requestMethod = "POST"
        connection.connectTimeout = 20_000
        connection.readTimeout = 90_000
        connection.doOutput = true
        connection.setRequestProperty("Authorization", "Bearer $key")
        connection.setRequestProperty("Content-Type", "application/json")
        connection.outputStream.use { it.write(body.toByteArray()) }
        val raw = parseResponse(connection, null)
        return JSONObject(raw).getJSONArray("choices").getJSONObject(0).getJSONObject("message").getString("content").trim()
    }

    private fun parseResponse(connection: HttpURLConnection, field: String?): String {
        val ok = connection.responseCode in 200..299
        val stream = if (ok) connection.inputStream else connection.errorStream
        val raw = stream.bufferedReader().use { it.readText() }
        if (!ok) {
            val message = try { JSONObject(raw).getJSONObject("error").optString("message") } catch (_: Exception) { "HTTP ${connection.responseCode}" }
            throw IllegalStateException(message.ifBlank { "OpenAI-Anfrage fehlgeschlagen" })
        }
        return if (field == null) raw else JSONObject(raw).getString(field).trim()
    }
}
