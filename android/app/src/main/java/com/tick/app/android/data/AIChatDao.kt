package com.tick.app.android.data

import androidx.room.Dao
import androidx.room.Insert
import androidx.room.Query
import androidx.room.Update
import kotlinx.coroutines.flow.Flow

@Dao
interface AIChatDao {
    @Insert
    suspend fun insert(session: AIChatSession): Long

    @Update
    suspend fun update(session: AIChatSession)

    @Query("DELETE FROM ai_chat_sessions WHERE id = :id")
    suspend fun deleteById(id: String)

    @Query("SELECT * FROM ai_chat_sessions ORDER BY updatedAt DESC")
    fun observeAll(): Flow<List<AIChatSession>>

    @Query("SELECT * FROM ai_chat_sessions WHERE id = :id")
    suspend fun getById(id: String): AIChatSession?

    @Query("SELECT * FROM ai_chat_sessions WHERE id = :id")
    fun observeById(id: String): Flow<AIChatSession?>
}