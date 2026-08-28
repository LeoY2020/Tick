package com.tick.app.android.data

import androidx.room.Dao
import androidx.room.Insert
import androidx.room.Query
import androidx.room.Update
import com.tick.app.android.model.Goal
import kotlinx.coroutines.flow.Flow

@Dao
interface GoalDao {
    @Insert
    suspend fun insert(goal: Goal): Long

    @Update
    suspend fun update(goal: Goal)

    @Query("DELETE FROM goals WHERE id = :id")
    suspend fun deleteById(id: String)

    @Query("SELECT * FROM goals ORDER BY createdAt ASC")
    fun observeAll(): Flow<List<Goal>>

    @Query("SELECT * FROM goals ORDER BY createdAt ASC")
    suspend fun getAll(): List<Goal>

    @Query("SELECT * FROM goals WHERE id = :id")
    suspend fun getById(id: String): Goal?

    @Query("SELECT * FROM goals WHERE id = :id")
    fun observeById(id: String): Flow<Goal?>
}