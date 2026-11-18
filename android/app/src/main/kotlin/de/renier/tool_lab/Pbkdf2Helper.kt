package de.renier.tool_lab

import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.StandardMethodCodec
import javax.crypto.SecretKeyFactory
import javax.crypto.spec.PBEKeySpec

object Pbkdf2Helper {
    private const val CHANNEL = "de.renier.tool_lab/pbkdf2"

    fun register(messenger: BinaryMessenger) {
        val queue = messenger.makeBackgroundTaskQueue()
        MethodChannel(messenger, CHANNEL, StandardMethodCodec.INSTANCE, queue)
            .setMethodCallHandler { call, result ->
                if (call.method != "deriveSha256") {
                    result.notImplemented()
                    return@setMethodCallHandler
                }
                val password = call.argument<String>("password")
                val salt = call.argument<ByteArray>("salt")
                val iterations = call.argument<Int>("iterations")
                val bits = call.argument<Int>("bits")
                if (password == null || salt == null || iterations == null || bits == null ||
                    iterations <= 0 || bits <= 0) {
                    result.error("INVALID_ARGUMENT", "Invalid PBKDF2 request", null)
                    return@setMethodCallHandler
                }
                // Same call cryptography_flutter made, so keys derived before stay identical.
                val spec = PBEKeySpec(password.toCharArray(), salt, iterations, bits)
                try {
                    val key = SecretKeyFactory.getInstance("PBKDF2WithHmacSHA256").generateSecret(spec)
                    result.success(key.encoded)
                } catch (e: Exception) {
                    result.error("PBKDF2", e.message, null)
                } finally {
                    spec.clearPassword()
                }
            }
    }
}
