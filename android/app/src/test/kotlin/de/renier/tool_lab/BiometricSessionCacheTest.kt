package de.renier.tool_lab

import org.junit.Assert.*
import org.junit.Test

class BiometricSessionCacheTest {
    @Test
    fun expiresFromAuthenticationWithoutSliding() {
        val cache = BiometricSessionCache<String>()
        cache.put("tool", "key", 1000)
        assertEquals("key" to 1000L, cache.get("tool", 30_000, 60_000))
        assertEquals("key" to 1000L, cache.get("tool", 60_999, 60_000))
        assertNull(cache.get("tool", 61_000, 60_000))
        assertNull(cache.get("tool", 61_001, 60_000))
    }

    @Test
    fun supportsImmediateExpiryAndDifferentTools() {
        val cache = BiometricSessionCache<String>()
        cache.put("first", "a", 1000)
        cache.put("second", "b", 1000)
        assertNull(cache.get("first", 1000, 0))
        assertEquals("b" to 1000L, cache.get("second", 1000, 60_000))
        assertNull(cache.get("second", 999, 60_000))
    }

    @Test
    fun oldTimerDoesNotRemoveNewSession() {
        val cache = BiometricSessionCache<String>()
        val old = cache.put("tool", "old", 1000)
        val current = cache.put("tool", "new", 2000)
        cache.removeIfCurrent("tool", old)
        assertEquals("new" to 2000L, cache.get("tool", 3000, 60_000))
        cache.removeIfCurrent("tool", current)
        assertNull(cache.get("tool", 3000, 60_000))
    }
}
