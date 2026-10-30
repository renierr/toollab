package de.renier.tool_lab

import android.content.Context
import android.os.Handler
import android.os.HandlerThread
import android.os.Looper
import android.os.SystemClock
import com.it_nomads.fluttersecurestorage.FlutterSecureStorage
import com.it_nomads.fluttersecurestorage.FlutterSecureStorageConfig
import com.it_nomads.fluttersecurestorage.SecurePreferencesCallback
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.atomic.AtomicBoolean

object ToolBiometricStorage {
    private const val CHANNEL = "de.renier.tool_lab/tool_biometric_storage"
    private val worker = HandlerThread("tool-biometric-storage").apply { start() }
    private val handler = Handler(worker.looper)
    private val main = Handler(Looper.getMainLooper())
    private val sessions = BiometricSessionCache<FlutterSecureStorage>()
    private val pending = mutableSetOf<String>()

    fun register(context: Context, messenger: BinaryMessenger) {
        val appContext = context.applicationContext
        MethodChannel(messenger, CHANNEL).setMethodCallHandler { call, result ->
            if (call.method !in listOf("read", "write", "delete")) {
                result.notImplemented()
                return@setMethodCallHandler
            }
            val key = call.argument<String>("key")
            val options = call.argument<Map<String, Any>>("options")
            val minutes = call.argument<Int>("minutes")
            val value = call.argument<String>("value")
            if (key.isNullOrEmpty() || options == null || minutes == null ||
                minutes !in 0..60 || (call.method == "write" && value == null)) {
                result.error("INVALID_ARGUMENT", "Invalid biometric storage request", null)
                return@setMethodCallHandler
            }
            handler.post {
                val config = FlutterSecureStorageConfig(options)
                val namespace = config.storageNamespace
                if (namespace.isNullOrEmpty() || !config.enforceBiometrics) {
                    main.post { result.error("INVALID_ARGUMENT", "Biometric namespace required", null) }
                    return@post
                }
                if (!pending.add(namespace)) {
                    main.post { result.error("BUSY", "Authentication already in progress", null) }
                    return@post
                }
                val duration = minutes * 60_000L
                val old = sessions.get(namespace, SystemClock.elapsedRealtime(), duration)
                // The plugin caches its decrypted storage key for its instance's lifetime.
                val storage = old?.first ?: FlutterSecureStorage(appContext)
                val completed = AtomicBoolean(false)
                try {
                    storage.initialize(config, object : SecurePreferencesCallback<Void> {
                        override fun onSuccess(unused: Void?) {
                            if (!completed.compareAndSet(false, true)) return
                            val authenticatedAt = old?.second ?: SystemClock.elapsedRealtime()
                            handler.post {
                                try {
                                    val prefixedKey = storage.addPrefixToKey(key)
                                    val output = when (call.method) {
                                        "read" -> if (storage.containsKey(prefixedKey)) storage.read(prefixedKey) else null
                                        "write" -> { storage.write(prefixedKey, value); null }
                                        else -> { storage.delete(prefixedKey); null }
                                    }
                                    if (call.method != "delete" && duration > 0) {
                                        val token = sessions.put(namespace, storage, authenticatedAt)
                                        val remaining = (duration - (SystemClock.elapsedRealtime() - authenticatedAt)).coerceAtLeast(0)
                                        handler.postDelayed({
                                            sessions.removeIfCurrent(namespace, token)
                                        }, remaining)
                                    } else {
                                        sessions.remove(namespace)
                                    }
                                    pending.remove(namespace)
                                    main.post { result.success(output) }
                                } catch (e: Exception) {
                                    sessions.remove(namespace)
                                    pending.remove(namespace)
                                    main.post { result.error("BIOMETRIC_STORAGE", e.message, null) }
                                }
                            }
                        }

                        override fun onError(e: Exception) {
                            if (!completed.compareAndSet(false, true)) return
                            handler.post {
                                sessions.remove(namespace)
                                pending.remove(namespace)
                                main.post { result.error("BIOMETRIC_STORAGE", e.message, null) }
                            }
                        }
                    })
                } catch (e: Exception) {
                    if (!completed.compareAndSet(false, true)) return@post
                    sessions.remove(namespace)
                    pending.remove(namespace)
                    main.post { result.error("BIOMETRIC_STORAGE", e.message, null) }
                }
            }
        }
    }
}
