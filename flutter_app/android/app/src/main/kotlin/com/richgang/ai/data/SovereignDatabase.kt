package com.richgang.ai.data

import androidx.room.Database
import androidx.room.RoomDatabase

/**
 * Isolated database. `exportSchema = false` is explicit: no schema
 * output directory is configured for this module, and this database
 * is not yet a production store.
 */
@Database(
    entities = [MessageEntity::class, ConversationFtsEntity::class],
    version = 1,
    exportSchema = false,
)
abstract class SovereignDatabase : RoomDatabase() {
    abstract fun sovereignDao(): SovereignDao
}
