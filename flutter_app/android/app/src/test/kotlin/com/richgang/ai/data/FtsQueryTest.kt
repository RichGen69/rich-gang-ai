package com.richgang.ai.data

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

/**
 * JVM-only tests for the pure-Kotlin [FtsQuery] helper. These need no
 * Android runtime and no Room database instance, so they are runnable
 * as plain unit tests. Fixtures here are generic example words only —
 * no production, mockup, or screenshot content is used as test data.
 *
 * A full Room round-trip test (insert via persistMessage, then MATCH
 * search) is deliberately NOT included: it needs an Android runtime
 * (Robolectric or a device) and this module is not device-verified.
 */
class FtsQueryTest {

    @Test
    fun phraseWrapsSingleWord() {
        assertEquals("\"hello\"", FtsQuery.phrase("hello"))
    }

    @Test
    fun phraseCollapsesWhitespace() {
        assertEquals("\"hello world\"", FtsQuery.phrase("  hello   world  "))
    }

    @Test
    fun phraseStripsDoubleQuotesInsteadOfEscapingThem() {
        assertEquals("\"hello world\"", FtsQuery.phrase("hello \"world\""))
    }

    @Test
    fun phraseReturnsNullForEmptyInput() {
        assertNull(FtsQuery.phrase(""))
        assertNull(FtsQuery.phrase("   "))
        assertNull(FtsQuery.phrase("\"\""))
    }

    @Test
    fun messageEntityDefaultsToUnassignedRowId() {
        val message = MessageEntity(
            timestamp = 1000L,
            sourceType = "test",
            content = "hello world",
            metadata = null,
        )
        assertEquals(0L, message.id)
    }
}
