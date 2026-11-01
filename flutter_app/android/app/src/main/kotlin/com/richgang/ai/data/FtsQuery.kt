package com.richgang.ai.data

/**
 * Pure-Kotlin FTS5 query shaping — no Android or Room dependency, so it
 * is unit-testable on the JVM (see FtsQueryTest).
 *
 * A bare user string is not a safe FTS5 expression: operators, quotes
 * and unbalanced parentheses throw SQLiteException at query time.
 * [phrase] turns arbitrary input into a single quoted phrase query:
 * double quotes are stripped (not escaped — an escaped quote inside a
 * phrase is still a phrase terminator risk), whitespace is collapsed,
 * and empty input yields null so the caller returns no rows instead of
 * issuing an empty MATCH.
 */
object FtsQuery {
    fun phrase(raw: String): String? {
        val cleaned = raw
            .replace('"', ' ')
            .split(Regex("\\s+"))
            .filter { it.isNotEmpty() }
            .joinToString(" ")
        if (cleaned.isEmpty()) return null
        return "\"$cleaned\""
    }
}
