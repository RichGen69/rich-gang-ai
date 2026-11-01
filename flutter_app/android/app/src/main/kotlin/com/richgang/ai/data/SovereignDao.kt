package com.richgang.ai.data

import androidx.room.Dao
import androidx.room.Delete
import androidx.room.Insert
import androidx.room.Query
import androidx.room.Transaction

/**
 * Abstract class (not an interface) so [persistMessage] can be a real
 * transactional helper over the abstract Room operations — the documented
 * Room pattern for transaction helpers, rather than relying on an
 * interface default method.
 *
 * Callers must use [persistMessage]/[searchMemoryFts] (or
 * [SovereignMemoryStore], which sanitises the query first). Never pass
 * raw user input straight into [searchMemoryFts]: a malformed FTS5
 * expression throws at query time. See [FtsQuery.phrase].
 */
@Dao
abstract class SovereignDao {

    @Insert
    abstract suspend fun insertMessageCore(message: MessageEntity): Long

    @Delete
    abstract suspend fun deleteMessage(message: MessageEntity)

    @Query("DELETE FROM conversation_history")
    abstract suspend fun clearAll()

    /**
     * Transaction-safe persist. The FTS index is maintained by Room's
     * contentEntity triggers inside this same transaction — no second,
     * separately-managed FTS insert is needed or allowed.
     */
    @Transaction
    open suspend fun persistMessage(message: MessageEntity): Long {
        return insertMessageCore(message)
    }

    /**
     * FTS5 MATCH search, most recent first, capped at 20 rows.
     * [query] must already be a valid FTS5 expression (see [FtsQuery]).
     * The join is on rowid: the FTS table's rowid is the content
     * table's rowid by construction (contentEntity).
     */
    @Query(
        """
        SELECT conversation_history.* FROM conversation_history
        JOIN conversation_fts ON conversation_history.id = conversation_fts.rowid
        WHERE conversation_fts MATCH :query
        ORDER BY conversation_history.timestamp DESC LIMIT 20
        """,
    )
    abstract suspend fun searchMemoryFts(query: String): List<MessageEntity>
}
