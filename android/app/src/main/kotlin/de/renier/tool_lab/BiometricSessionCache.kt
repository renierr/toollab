package de.renier.tool_lab

internal class BiometricSessionCache<T> {
    private data class Entry<T>(val value: T, val authenticatedAt: Long, val token: Long)

    private val entries = mutableMapOf<String, Entry<T>>()
    private var nextToken = 0L

    fun get(key: String, now: Long, duration: Long): Pair<T, Long>? {
        val entry = entries[key] ?: return null
        if (duration <= 0 || now < entry.authenticatedAt || now - entry.authenticatedAt >= duration) {
            entries.remove(key)
            return null
        }
        return entry.value to entry.authenticatedAt
    }

    fun put(key: String, value: T, authenticatedAt: Long): Long {
        val token = ++nextToken
        entries[key] = Entry(value, authenticatedAt, token)
        return token
    }

    fun remove(key: String) { entries.remove(key) }

    fun removeIfCurrent(key: String, token: Long) {
        if (entries[key]?.token == token) entries.remove(key)
    }
}
