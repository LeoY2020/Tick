using Microsoft.Data.Sqlite;

namespace Tick.Data;

/// <summary>
/// SQLite 数据库：打开连接、初始化四张表（Goal / TaskItem / AIChatSession / Settings），
/// 并启用外键（自引用 TaskItem.ParentTaskId 与 Goal 级联删除依赖 foreign_keys=ON）。
/// </summary>
public sealed class AppDatabase : IDisposable
{
    private readonly SqliteConnection _connection;

    public string DatabasePath { get; }

    public SqliteConnection Connection => _connection;

    public AppDatabase(string? databasePath = null)
    {
        DatabasePath = databasePath ?? DefaultDatabasePath();
        var dir = Path.GetDirectoryName(DatabasePath);
        if (!string.IsNullOrEmpty(dir))
            Directory.CreateDirectory(dir);

        _connection = new SqliteConnection($"Data Source={DatabasePath}");
        _connection.Open();
        using var pragma = _connection.CreateCommand();
        pragma.CommandText = "PRAGMA foreign_keys = ON;";
        pragma.ExecuteNonQuery();
        EnsureSchema();
    }

    /// <summary>默认数据库路径：%LOCALAPPDATA%\Tick\tick.db</summary>
    public static string DefaultDatabasePath()
    {
        var baseDir = Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData);
        return Path.Combine(baseDir, "Tick", "tick.db");
    }

    private void EnsureSchema()
    {
        const string schema = """
            CREATE TABLE IF NOT EXISTS Goal (
                Id TEXT PRIMARY KEY,
                Name TEXT NOT NULL,
                ColorHex TEXT NOT NULL,
                IconSystemName TEXT NULL,
                StartDate TEXT NULL,
                EndDate TEXT NULL,
                StartDatePreciseToHour INTEGER NOT NULL DEFAULT 0,
                EndDatePreciseToHour INTEGER NOT NULL DEFAULT 0,
                CreatedAt TEXT NOT NULL,
                ProgressCountingModeRaw TEXT NOT NULL
            );

            CREATE TABLE IF NOT EXISTS TaskItem (
                Id TEXT PRIMARY KEY,
                Name TEXT NOT NULL,
                ColorHex TEXT NULL,
                IconSystemName TEXT NULL,
                TypeRaw TEXT NOT NULL,
                StatusRaw TEXT NOT NULL,
                TotalAmount REAL NOT NULL DEFAULT 0,
                CurrentAmount REAL NOT NULL DEFAULT 0,
                StartDate TEXT NULL,
                EndDate TEXT NULL,
                ReminderDate TEXT NULL,
                RepeatRuleRaw TEXT NULL,
                CustomWeekdaysRaw TEXT NULL,
                CreatedAt TEXT NOT NULL,
                SortOrder INTEGER NOT NULL DEFAULT 0,
                GoalId TEXT NULL REFERENCES Goal(Id) ON DELETE CASCADE,
                ParentTaskId TEXT NULL REFERENCES TaskItem(Id) ON DELETE CASCADE
            );

            CREATE TABLE IF NOT EXISTS AIChatSession (
                Id TEXT PRIMARY KEY,
                Title TEXT NOT NULL,
                CreatedAt TEXT NOT NULL,
                UpdatedAt TEXT NOT NULL,
                MessagesJson TEXT NOT NULL,
                MessageCount INTEGER NOT NULL DEFAULT 0,
                AttachmentName TEXT NULL,
                AttachmentText TEXT NULL
            );

            CREATE TABLE IF NOT EXISTS Settings (
                Key TEXT PRIMARY KEY,
                Value TEXT NOT NULL
            );

            CREATE INDEX IF NOT EXISTS idx_task_goal ON TaskItem(GoalId);
            CREATE INDEX IF NOT EXISTS idx_task_parent ON TaskItem(ParentTaskId);
            """;

        using var cmd = _connection.CreateCommand();
        cmd.CommandText = schema;
        cmd.ExecuteNonQuery();
    }

    public void Dispose()
    {
        _connection?.Dispose();
    }
}