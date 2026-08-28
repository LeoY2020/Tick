package com.tick.app.android.data

import androidx.room.Dao
import androidx.room.Insert
import androidx.room.Query
import androidx.room.Update
import com.tick.app.android.model.TaskItem
import kotlinx.coroutines.flow.Flow

@Dao
interface TaskDao {
    @Insert
    suspend fun insert(task: TaskItem): Long

    @Update
    suspend fun update(task: TaskItem)

    @Query("DELETE FROM tasks WHERE id = :id")
    suspend fun deleteById(id: String)

    @Query("SELECT * FROM tasks WHERE id = :id")
    suspend fun getById(id: String): TaskItem?

    @Query("SELECT * FROM tasks WHERE goalId = :goalId ORDER BY sortOrder ASC, createdAt ASC")
    fun observeByGoal(goalId: String): Flow<List<TaskItem>>

    @Query("SELECT * FROM tasks WHERE goalId = :goalId ORDER BY sortOrder ASC, createdAt ASC")
    suspend fun getByGoal(goalId: String): List<TaskItem>

    /** 读取全部任务（用于内存建树，保留所有层级后代） */
    @Query("SELECT * FROM tasks")
    fun observeAll(): Flow<List<TaskItem>>

    @Query("SELECT * FROM tasks")
    suspend fun getAll(): List<TaskItem>

    /** 仅清空 tasks 表（导入时使用，不依赖外键级联） */
    @Query("DELETE FROM tasks")
    suspend fun deleteAll(): Int

    /** 读取某个 goal 下所有任务（含后代的扁平表），导入恢复时按树重建 */
    @Query("SELECT * FROM tasks WHERE goalId = :goalId")
    suspend fun getFlatByGoal(goalId: String): List<TaskItem>
}