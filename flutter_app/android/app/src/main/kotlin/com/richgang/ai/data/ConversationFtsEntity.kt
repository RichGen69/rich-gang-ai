package com.richgang.ai.data

import androidx.room.ColumnInfo
import androidx.room.Entity
import androidx.room.Fts5
import androidx.room.PrimaryKey

/**
 * FTS5 index over [MessageEntity.content].
 *
 * Corrections to the pasted snippet:
 * - The FTS entity MUST declare a primary key named `rowid`. The pasted
 *   version had `@ColumnInfo(name = "rowid")` with no `@PrimaryKey`,
 *   which Room rejects for an FTS entity.
 * - `contentEntity = MessageEntity::class`: Room generates triggers so
 *   inserts/updates/deletes on conversation_history keep this index in
 *   sync in the same transaction. The pasted version manually inserted
 *   into both tables on insert only, so any later update or delete
 *   would have left the FTS index stale. There is therefore no manual
 *   FTS insert in the DAO — inserting the message is enough.
 * - Only `content` is indexed, deliberately: sourceType/metadata are
 *   not full-text searchable in this module.
 */
@Fts5(contentEntity = MessageEntity::class)
@Entity(tableName = "conversation_fts")
data class ConversationFtsEntity(
    @PrimaryKey
    @ColumnInfo(name = "rowid")
    val rowId: Long,
    val content: String,
)
