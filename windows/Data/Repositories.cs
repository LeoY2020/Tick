using System.Globalization;
using Microsoft.Data.Sqlite;
using Tick.Models;

namespace Tick.Data;

/// <summary>数据库值 / 模型之间的日期映射辅助</summary>
internal static class DbMapper
{
    public static string? Date(DateTime? dt) => dt?.ToString("O");

    public static DateTime? Date(string? s) =>
        string.IsNullOrEmpty(s)
            ? null
            : DateTime.Parse(s, CultureInfo.InvariantCulture, DateTimeStyles.RoundtripKind);

    public static int Bool(bool b) => b ? 1 : 0;
}

/// <summary>目标仓储：加载 / 插入 / 更新 / 删除（含任务树）</summary>
public sealed class GoalRepository
{
    private readonly SqliteConnection _conn;

    public GoalRepository(SqliteConnection conn) => _conn = conn;

    public List<Goal> LoadAll()
    {
        var goals = new List<Goal>();
        using var cmd = _conn.CreateCommand();
        cmd.CommandText = "SELECT * FROM Goal ORDER BY CreatedAt ASC;";
        using var reader = cmd.ExecuteReader();
        while (reader.Read())
            goals.Add(ReadGoal(reader));
        return goals;
    }

    public Goal? Load(Guid id)
    {
        using var cmd = _conn.CreateCommand();
        cmd.CommandText = "SELECT * FROM Goal WHERE Id = $id;";
        cmd.Parameters.AddWithValue("$id", id.ToString());
        using var reader = cmd.ExecuteReader();
        return reader.Read() ? ReadGoal(reader) : null;
    }

    public void Save(Goal goal)
    {
        using var tx = _conn.BeginTransaction();
        using (var cmd = _conn.CreateCommand())
        {
            cmd.Transaction = tx;
            cmd.CommandText = """
                INSERT INTO Goal (Id, Name, ColorHex, IconSystemName, StartDate, EndDate,
                                  StartDatePreciseToHour, EndDatePreciseToHour, CreatedAt, ProgressCountingModeRaw)
                VALUES ($id, $name, $colorHex, $icon, $startDate, $endDate,
                        $startPrecise, $endPrecise, $createdAt, $modeRaw)
                ON CONFLICT(Id) DO UPDATE SET
                    Name = excluded.Name,
                    ColorHex = excluded.ColorHex,
                    IconSystemName = excluded.IconSystemName,
                    StartDate = excluded.StartDate,
                    EndDate = excluded.EndDate,
                    StartDatePreciseToHour = excluded.StartDatePreciseToHour,
                    EndDatePreciseToHour = excluded.EndDatePreciseToHour,
                    CreatedAt = excluded.CreatedAt,
                    ProgressCountingModeRaw = excluded.ProgressCountingModeRaw;
                """;
            AddGoalParams(cmd, goal);
            cmd.ExecuteNonQuery();
        }
        tx.Commit();
    }

    public void Delete(Guid id)
    {
        using var cmd = _conn.CreateCommand();
        cmd.CommandText = "DELETE FROM Goal WHERE Id = $id;"; // FK 级联删除其任务树
        cmd.Parameters.AddWithValue("$id", id.ToString());
        cmd.ExecuteNonQuery();
    }

    private static Goal ReadGoal(SqliteDataReader r)
    {
        return new Goal
        {
            Id = Guid.Parse(r.GetString(r.GetOrdinal("Id"))),
            Name = r.GetString(r.GetOrdinal("Name")),
            ColorHex = r.GetString(r.GetOrdinal("ColorHex")),
            IconSystemName = r.IsDBNull(r.GetOrdinal("IconSystemName")) ? null : r.GetString(r.GetOrdinal("IconSystemName")),
            StartDate = DbMapper.Date(r.IsDBNull(r.GetOrdinal("StartDate")) ? null : r.GetString(r.GetOrdinal("StartDate"))),
            EndDate = DbMapper.Date(r.IsDBNull(r.GetOrdinal("EndDate")) ? null : r.GetString(r.GetOrdinal("EndDate"))),
            StartDatePreciseToHour = r.GetInt64(r.GetOrdinal("StartDatePreciseToHour")) != 0,
            EndDatePreciseToHour = r.GetInt64(r.GetOrdinal("EndDatePreciseToHour")) != 0,
            CreatedAt = DateTime.Parse(r.GetString(r.GetOrdinal("CreatedAt")), CultureInfo.InvariantCulture, DateTimeStyles.RoundtripKind),
            ProgressCountingModeRaw = r.GetString(r.GetOrdinal("ProgressCountingModeRaw")),
        };
    }

    private static void AddGoalParams(SqliteCommand cmd, Goal goal)
    {
        cmd.Parameters.AddWithValue("$id", goal.Id.ToString());
        cmd.Parameters.AddWithValue("$name", goal.Name);
        cmd.Parameters.AddWithValue("$colorHex", goal.ColorHex);
        cmd.Parameters.AddWithValue("$icon", (object?)goal.IconSystemName ?? DBNull.Value);
        cmd.Parameters.AddWithValue("$startDate", (object?)DbMapper.Date(goal.StartDate) ?? DBNull.Value);
        cmd.Parameters.AddWithValue("$endDate", (object?)DbMapper.Date(goal.EndDate) ?? DBNull.Value);
        cmd.Parameters.AddWithValue("$startPrecise", DbMapper.Bool(goal.StartDatePreciseToHour));
        cmd.Parameters.AddWithValue("$endPrecise", DbMapper.Bool(goal.EndDatePreciseToHour));
        cmd.Parameters.AddWithValue("$createdAt", goal.CreatedAt.ToString("O"));
        cmd.Parameters.AddWithValue("$modeRaw", goal.ProgressCountingModeRaw);
    }
}

/// <summary>
/// 任务仓储：加载任务树、保存（递归 upsert）、按需删除。
/// 自引用级联删除由 SQLite 外键（ON DELETE CASCADE）保证。
/// </summary>
public sealed class TaskRepository
{
    private readonly SqliteConnection _conn;

    public TaskRepository(SqliteConnection conn) => _conn = conn;

    /// <summary>加载 goal 的完整任务树（递归 CTE），填充 goal.Tasks 并返回顶层列表</summary>
    public List<TaskItem> LoadTreeFor(Goal goal)
    {
        const string sql = """
            WITH RECURSIVE tree(id) AS (
                SELECT Id FROM TaskItem WHERE GoalId = $goalId
                UNION ALL
                SELECT t.Id FROM TaskItem t JOIN tree r ON t.ParentTaskId = r.id
            )
            SELECT * FROM TaskItem WHERE Id IN (SELECT Id FROM tree)
            ORDER BY SortOrder ASC, CreatedAt ASC;
            """;

        var rows = new List<TaskItem>();
        using (var cmd = _conn.CreateCommand())
        {
            cmd.CommandText = sql;
            cmd.Parameters.AddWithValue("$goalId", goal.Id.ToString());
            using var reader = cmd.ExecuteReader();
            while (reader.Read())
                rows.Add(ReadTask(reader));
        }

        return BuildTree(rows, goal);
    }

    /// <summary>根据父链 / 目标 Id 建立对象图，返回顶层任务列表</summary>
    public static List<TaskItem> BuildTree(List<TaskItem> rows, Goal goal)
    {
        var byId = rows.ToDictionary(t => t.Id);
        var roots = new List<TaskItem>();
        foreach (var task in rows)
        {
            if (task.ParentTaskId is Guid parentId && byId.TryGetValue(parentId, out var parent))
            {
                task.ParentTask = parent;
                parent.Subtasks.Add(task);
            }
            else
            {
                task.Goal = goal;
                roots.Add(task);
            }
        }
        goal.Tasks.Clear();
        goal.Tasks.AddRange(roots);
        return roots;
    }

    /// <summary>递归保存任务（及全部后代），使用 upsert 避免 REPLACE 触发外键级联删除</summary>
    public void Save(TaskItem task)
    {
        using var tx = _conn.BeginTransaction();
        SaveRecursive(task, tx);
        tx.Commit();
    }

    private void SaveRecursive(TaskItem task, SqliteTransaction tx)
    {
        using var cmd = _conn.CreateCommand();
        cmd.Transaction = tx;
        cmd.CommandText = """
            INSERT INTO TaskItem (Id, Name, ColorHex, IconSystemName, TypeRaw, StatusRaw,
                                  TotalAmount, CurrentAmount, StartDate, EndDate, ReminderDate,
                                  RepeatRuleRaw, CustomWeekdaysRaw, CreatedAt, SortOrder, GoalId, ParentTaskId)
            VALUES ($id, $name, $colorHex, $icon, $typeRaw, $statusRaw,
                    $total, $current, $startDate, $endDate, $reminderDate,
                    $repeatRaw, $weekdaysRaw, $createdAt, $sortOrder, $goalId, $parentId)
            ON CONFLICT(Id) DO UPDATE SET
                Name = excluded.Name,
                ColorHex = excluded.ColorHex,
                IconSystemName = excluded.IconSystemName,
                TypeRaw = excluded.TypeRaw,
                StatusRaw = excluded.StatusRaw,
                TotalAmount = excluded.TotalAmount,
                CurrentAmount = excluded.CurrentAmount,
                StartDate = excluded.StartDate,
                EndDate = excluded.EndDate,
                ReminderDate = excluded.ReminderDate,
                RepeatRuleRaw = excluded.RepeatRuleRaw,
                CustomWeekdaysRaw = excluded.CustomWeekdaysRaw,
                CreatedAt = excluded.CreatedAt,
                SortOrder = excluded.SortOrder,
                GoalId = excluded.GoalId,
                ParentTaskId = excluded.ParentTaskId;
            """;
        AddTaskParams(cmd, task);
        cmd.ExecuteNonQuery();

        foreach (var sub in task.Subtasks)
            SaveRecursive(sub, tx);
    }

    public void Delete(Guid id)
    {
        using var cmd = _conn.CreateCommand();
        cmd.CommandText = "DELETE FROM TaskItem WHERE Id = $id;"; // FK 级联删除子树
        cmd.Parameters.AddWithValue("$id", id.ToString());
        cmd.ExecuteNonQuery();
    }

    private static TaskItem ReadTask(SqliteDataReader r)
    {
        var task = new TaskItem
        {
            Id = Guid.Parse(r.GetString(r.GetOrdinal("Id"))),
            Name = r.GetString(r.GetOrdinal("Name")),
            ColorHex = r.IsDBNull(r.GetOrdinal("ColorHex")) ? null : r.GetString(r.GetOrdinal("ColorHex")),
            IconSystemName = r.IsDBNull(r.GetOrdinal("IconSystemName")) ? null : r.GetString(r.GetOrdinal("IconSystemName")),
            TypeRaw = r.GetString(r.GetOrdinal("TypeRaw")),
            StatusRaw = r.GetString(r.GetOrdinal("StatusRaw")),
            TotalAmount = r.GetDouble(r.GetOrdinal("TotalAmount")),
            CurrentAmount = r.GetDouble(r.GetOrdinal("CurrentAmount")),
            StartDate = DbMapper.Date(r.IsDBNull(r.GetOrdinal("StartDate")) ? null : r.GetString(r.GetOrdinal("StartDate"))),
            EndDate = DbMapper.Date(r.IsDBNull(r.GetOrdinal("EndDate")) ? null : r.GetString(r.GetOrdinal("EndDate"))),
            ReminderDate = DbMapper.Date(r.IsDBNull(r.GetOrdinal("ReminderDate")) ? null : r.GetString(r.GetOrdinal("ReminderDate"))),
            RepeatRuleRaw = r.IsDBNull(r.GetOrdinal("RepeatRuleRaw")) ? null : r.GetString(r.GetOrdinal("RepeatRuleRaw")),
            CustomWeekdaysRaw = r.IsDBNull(r.GetOrdinal("CustomWeekdaysRaw")) ? null : r.GetString(r.GetOrdinal("CustomWeekdaysRaw")),
            CreatedAt = DateTime.Parse(r.GetString(r.GetOrdinal("CreatedAt")), CultureInfo.InvariantCulture, DateTimeStyles.RoundtripKind),
            SortOrder = (int)r.GetInt64(r.GetOrdinal("SortOrder")),
            GoalId = r.IsDBNull(r.GetOrdinal("GoalId")) ? null : Guid.Parse(r.GetString(r.GetOrdinal("GoalId"))),
            ParentTaskId = r.IsDBNull(r.GetOrdinal("ParentTaskId")) ? null : Guid.Parse(r.GetString(r.GetOrdinal("ParentTaskId"))),
        };
        return task;
    }

    private static void AddTaskParams(SqliteCommand cmd, TaskItem task)
    {
        cmd.Parameters.AddWithValue("$id", task.Id.ToString());
        cmd.Parameters.AddWithValue("$name", task.Name);
        cmd.Parameters.AddWithValue("$colorHex", (object?)task.ColorHex ?? DBNull.Value);
        cmd.Parameters.AddWithValue("$icon", (object?)task.IconSystemName ?? DBNull.Value);
        cmd.Parameters.AddWithValue("$typeRaw", task.TypeRaw);
        cmd.Parameters.AddWithValue("$statusRaw", task.StatusRaw);
        cmd.Parameters.AddWithValue("$total", task.TotalAmount);
        cmd.Parameters.AddWithValue("$current", task.CurrentAmount);
        cmd.Parameters.AddWithValue("$startDate", (object?)DbMapper.Date(task.StartDate) ?? DBNull.Value);
        cmd.Parameters.AddWithValue("$endDate", (object?)DbMapper.Date(task.EndDate) ?? DBNull.Value);
        cmd.Parameters.AddWithValue("$reminderDate", (object?)DbMapper.Date(task.ReminderDate) ?? DBNull.Value);
        cmd.Parameters.AddWithValue("$repeatRaw", (object?)task.RepeatRuleRaw ?? DBNull.Value);
        cmd.Parameters.AddWithValue("$weekdaysRaw", (object?)task.CustomWeekdaysRaw ?? DBNull.Value);
        cmd.Parameters.AddWithValue("$createdAt", task.CreatedAt.ToString("O"));
        cmd.Parameters.AddWithValue("$sortOrder", task.SortOrder);
        cmd.Parameters.AddWithValue("$goalId", (object?)task.GoalId?.ToString() ?? DBNull.Value);
        cmd.Parameters.AddWithValue("$parentId", (object?)task.ParentTaskId?.ToString() ?? DBNull.Value);
    }
}

/// <summary>AI 聊天会话仓储</summary>
public sealed class ChatRepository
{
    private readonly SqliteConnection _conn;

    public ChatRepository(SqliteConnection conn) => _conn = conn;

    public List<AIChatSession> LoadAll()
    {
        var result = new List<AIChatSession>();
        using var cmd = _conn.CreateCommand();
        cmd.CommandText = "SELECT * FROM AIChatSession ORDER BY UpdatedAt DESC;";
        using var reader = cmd.ExecuteReader();
        while (reader.Read())
            result.Add(ReadSession(reader));
        return result;
    }

    public void Save(AIChatSession session)
    {
        using var cmd = _conn.CreateCommand();
        cmd.CommandText = """
            INSERT INTO AIChatSession (Id, Title, CreatedAt, UpdatedAt, MessagesJson, MessageCount, AttachmentName, AttachmentText)
            VALUES ($id, $title, $createdAt, $updatedAt, $messagesJson, $messageCount, $attachmentName, $attachmentText)
            ON CONFLICT(Id) DO UPDATE SET
                Title = excluded.Title,
                UpdatedAt = excluded.UpdatedAt,
                MessagesJson = excluded.MessagesJson,
                MessageCount = excluded.MessageCount,
                AttachmentName = excluded.AttachmentName,
                AttachmentText = excluded.AttachmentText;
            """;
        cmd.Parameters.AddWithValue("$id", session.Id.ToString());
        cmd.Parameters.AddWithValue("$title", session.Title);
        cmd.Parameters.AddWithValue("$createdAt", session.CreatedAt.ToString("O"));
        cmd.Parameters.AddWithValue("$updatedAt", session.UpdatedAt.ToString("O"));
        cmd.Parameters.AddWithValue("$messagesJson", session.MessagesJson);
        cmd.Parameters.AddWithValue("$messageCount", session.MessageCount);
        cmd.Parameters.AddWithValue("$attachmentName", (object?)session.AttachmentName ?? DBNull.Value);
        cmd.Parameters.AddWithValue("$attachmentText", (object?)session.AttachmentText ?? DBNull.Value);
        cmd.ExecuteNonQuery();
    }

    public void Delete(Guid id)
    {
        using var cmd = _conn.CreateCommand();
        cmd.CommandText = "DELETE FROM AIChatSession WHERE Id = $id;";
        cmd.Parameters.AddWithValue("$id", id.ToString());
        cmd.ExecuteNonQuery();
    }

    private static AIChatSession ReadSession(SqliteDataReader r)
    {
        return new AIChatSession
        {
            Id = Guid.Parse(r.GetString(r.GetOrdinal("Id"))),
            Title = r.GetString(r.GetOrdinal("Title")),
            CreatedAt = DateTime.Parse(r.GetString(r.GetOrdinal("CreatedAt")), CultureInfo.InvariantCulture, DateTimeStyles.RoundtripKind),
            UpdatedAt = DateTime.Parse(r.GetString(r.GetOrdinal("UpdatedAt")), CultureInfo.InvariantCulture, DateTimeStyles.RoundtripKind),
            MessagesJson = r.GetString(r.GetOrdinal("MessagesJson")),
            MessageCount = (int)r.GetInt64(r.GetOrdinal("MessageCount")),
            AttachmentName = r.IsDBNull(r.GetOrdinal("AttachmentName")) ? null : r.GetString(r.GetOrdinal("AttachmentName")),
            AttachmentText = r.IsDBNull(r.GetOrdinal("AttachmentText")) ? null : r.GetString(r.GetOrdinal("AttachmentText")),
        };
    }
}

/// <summary>设置存储（Key / Value 表）</summary>
public sealed class SettingsRepository
{
    private readonly SqliteConnection _conn;

    public SettingsRepository(SqliteConnection conn) => _conn = conn;

    public string? Get(string key)
    {
        using var cmd = _conn.CreateCommand();
        cmd.CommandText = "SELECT Value FROM Settings WHERE Key = $key;";
        cmd.Parameters.AddWithValue("$key", key);
        var result = cmd.ExecuteScalar();
        return result as string;
    }

    public void Set(string key, string value)
    {
        using var cmd = _conn.CreateCommand();
        cmd.CommandText = """
            INSERT INTO Settings (Key, Value) VALUES ($key, $value)
            ON CONFLICT(Key) DO UPDATE SET Value = excluded.Value;
            """;
        cmd.Parameters.AddWithValue("$key", key);
        cmd.Parameters.AddWithValue("$value", value);
        cmd.ExecuteNonQuery();
    }

    public Dictionary<string, string> GetAll()
    {
        var result = new Dictionary<string, string>();
        using var cmd = _conn.CreateCommand();
        cmd.CommandText = "SELECT Key, Value FROM Settings;";
        using var reader = cmd.ExecuteReader();
        while (reader.Read())
            result[reader.GetString(0)] = reader.GetString(1);
        return result;
    }
}