package de.renier.tool_lab

import android.content.Context
import android.os.Handler
import android.os.Looper
import android.speech.tts.TextToSpeech
import android.speech.tts.UtteranceProgressListener
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel
import java.util.Locale

/** Reads text aloud with the system text-to-speech engine. */
object TextToSpeechHelper {
    private const val CHANNEL = "de.renier.tool_lab/tts"

    private val main = Handler(Looper.getMainLooper())
    private var engine: TextToSpeech? = null
    private var ready = false
    private val waiting = mutableListOf<(Boolean) -> Unit>()
    private var pending: MethodChannel.Result? = null
    private var utterancePrefix: String? = null
    private var lastUtterance: String? = null

    fun register(context: Context, messenger: BinaryMessenger) {
        val app = context.applicationContext
        MethodChannel(messenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "speak" -> {
                    val text = call.argument<String>("text").orEmpty()
                    val language = call.argument<String>("language")
                    withEngine(app) { ok ->
                        if (ok) speak(text, language, result)
                        else result.error("unavailable", "No text-to-speech engine", null)
                    }
                }
                "isLanguageAvailable" -> {
                    val language = call.argument<String>("language").orEmpty()
                    withEngine(app) { ok -> result.success(ok && isAvailable(language)) }
                }
                "stop" -> {
                    finish(false)
                    engine?.stop()
                    result.success(null)
                }
                "release" -> {
                    release()
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun withEngine(context: Context, action: (Boolean) -> Unit) {
        if (ready) {
            action(true)
            return
        }
        waiting.add(action)
        if (engine != null) return
        var created: TextToSpeech? = null
        created = TextToSpeech(context) { status ->
            main.post {
                if (engine !== created) return@post
                ready = status == TextToSpeech.SUCCESS
                if (ready) {
                    created?.setOnUtteranceProgressListener(listener)
                } else {
                    created?.shutdown()
                    engine = null
                }
                val calls = waiting.toList()
                waiting.clear()
                calls.forEach { it(ready) }
            }
        }
        engine = created
    }

    private fun isAvailable(language: String): Boolean {
        val result = engine?.isLanguageAvailable(Locale.forLanguageTag(language)) ?: return false
        return result >= TextToSpeech.LANG_AVAILABLE
    }

    private fun speak(text: String, language: String?, result: MethodChannel.Result) {
        val tts = engine ?: return result.error("unavailable", "No text-to-speech engine", null)
        if (language != null) {
            val set = tts.setLanguage(Locale.forLanguageTag(language))
            if (set == TextToSpeech.LANG_MISSING_DATA || set == TextToSpeech.LANG_NOT_SUPPORTED) {
                result.error("language_unavailable", language, null)
                return
            }
        }
        finish(false)
        tts.stop()
        val chunks = split(text, TextToSpeech.getMaxSpeechInputLength() - 100)
        if (chunks.isEmpty()) {
            result.success(true)
            return
        }
        val prefix = "toollab_${System.nanoTime()}"
        pending = result
        utterancePrefix = prefix
        lastUtterance = "$prefix:${chunks.size - 1}"
        chunks.forEachIndexed { i, chunk ->
            tts.speak(chunk, TextToSpeech.QUEUE_ADD, null, "$prefix:$i")
        }
    }

    /** Splits at sentence ends, so no chunk exceeds the engine's input limit. */
    private fun split(text: String, max: Int): List<String> {
        val chunks = mutableListOf<String>()
        val current = StringBuilder()
        for (sentence in text.split(Regex("(?<=[.!?\\n])\\s+"))) {
            if (sentence.isBlank()) continue
            if (current.isNotEmpty() && current.length + sentence.length + 1 > max) {
                chunks.add(current.toString())
                current.clear()
            }
            var rest = sentence
            while (rest.length > max) {
                chunks.add(rest.substring(0, max))
                rest = rest.substring(max)
            }
            if (current.isNotEmpty()) current.append(' ')
            current.append(rest)
        }
        if (current.isNotBlank()) chunks.add(current.toString())
        return chunks
    }

    private fun finish(done: Boolean) {
        val result = pending ?: return
        pending = null
        utterancePrefix = null
        lastUtterance = null
        result.success(done)
    }

    private fun release() {
        finish(false)
        engine?.stop()
        engine?.shutdown()
        engine = null
        ready = false
        val calls = waiting.toList()
        waiting.clear()
        calls.forEach { it(false) }
    }

    private val listener = object : UtteranceProgressListener() {
        override fun onStart(utteranceId: String?) {}

        override fun onDone(utteranceId: String?) {
            main.post { if (utteranceId != null && utteranceId == lastUtterance) finish(true) }
        }

        @Deprecated("Deprecated in Java")
        override fun onError(utteranceId: String?) {
            main.post {
                val prefix = utterancePrefix
                if (prefix != null && utteranceId?.startsWith(prefix) == true) finish(false)
            }
        }
    }
}
