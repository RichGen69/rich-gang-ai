package com.richgang.ai.data

import androidx.room.Entity
import androidx.room.PrimaryKey

/**
 * ISOLATED Room module (2026-10-30). Not wired into DreamCycleService,
 * any chat view, or the Rust rusqlite store. Room vs. Rust rusqlite as the
 * single source of truth is still undecided — this table must not be
 * treated as live production persistence until that decision is made.
 *
 * The primary key is the SQLite rowid: [id] is left at 0 on insert and
 * Room assigns the rowid. That is what the FTS table joins on.
 */
@Entity(tableName = "conversation_history")
data class MessageEntity(
    @PrimaryKey(autoGenerate = true) val id: Long = 0,
    val timestamp: Long,
    val sourceType: String,
    val content: String,
    val metadata: String?,
)
