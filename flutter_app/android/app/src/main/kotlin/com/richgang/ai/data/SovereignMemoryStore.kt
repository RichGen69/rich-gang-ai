package com.richgang.ai.data

import android.content.Context
import androidx.room.Room

/**
 * Small builder + safe-access helper for the isolated Room module.
 *
 * This is the only intended entry point once the module is wired in
 * (it is NOT wired in yet). It keeps raw input away from the DAO's
 * MATCH query: an empty/unsearchable query returns an empty list
 * instead of issuing a MATCH at all.
 *
 * NOTE: [Context] is genuinely used here (Room.databaseBuilder), unlike
 * in the pasted snippet, where it was an unused import.
 */
object SovereignDatabaseBuilder {
    fun create(context: Context, name: String = "sovereign_memory.db"): SovereignDatabase {
        return Room.databaseBuilder(
            context.applicationContext,
            SovereignDatabase::class.java,
            name,
        ).build()
    }

    fun createInMemory(context: Context): SovereignDatabase {
        return Room.inMemoryDatabaseBuilder(
            context.applicationContext,
            SovereignDatabase::class.java,
        ).build()
    }
}

class SovereignMemoryStore(private val dao: SovereignDao) {
    suspend fun persist(message: MessageEntity): Long = dao.persistMessage(message)

    suspend fun search(rawQuery: String): List<MessageEntity> {
        val ftsQuery = FtsQuery.phrase(rawQuery) ?: return emptyList()
        return dao.searchMemoryFts(ftsQuery)
    }
}
