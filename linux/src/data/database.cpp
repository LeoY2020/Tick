#include "data/database.h"

#include <QDir>
#include <QSqlError>
#include <QSqlQuery>
#include <QStandardPaths>
#include <QStringList>

namespace tick {

Database::Database() : db_(QSqlDatabase::addDatabase("QSQLITE", "tick_main")) {}

Database& Database::instance() {
    static Database s_instance;
    return s_instance;
}

bool Database::initialize(const QString& path) {
    QString p = path;
    if (p.isEmpty()) {
        QDir dir(QStandardPaths::writableLocation(QStandardPaths::AppDataLocation));
        dir.mkpath(".");
        p = dir.filePath(QStringLiteral("tick.db"));
    }
    db_.setDatabaseName(p);
    if (!db_.open()) {
        return false;
    }
    return createSchema();
}

QSqlDatabase Database::connection() const {
    return db_;
}

bool Database::isOpen() const {
    return db_.isOpen();
}

QString Database::errorString() const {
    return db_.lastError().text();
}

bool Database::createSchema() {
    const QStringList statements = {
        QStringLiteral("PRAGMA foreign_keys = ON;"),
        QStringLiteral(
            "CREATE TABLE IF NOT EXISTS Goal ("
            "id TEXT PRIMARY KEY,"
            "name TEXT NOT NULL,"
            "color_hex TEXT NOT NULL DEFAULT 'auto',"
            "icon_system_name TEXT,"
            "start_date TEXT,"
            "end_date TEXT,"
            "start_date_precise_to_hour INTEGER NOT NULL DEFAULT 0,"
            "end_date_precise_to_hour INTEGER NOT NULL DEFAULT 0,"
            "created_at TEXT NOT NULL,"
            "progress_counting_mode TEXT NOT NULL DEFAULT 'allTasks'"
            ")"),
        QStringLiteral(
            "CREATE TABLE IF NOT EXISTS TaskItem ("
            "id TEXT PRIMARY KEY,"
            "goal_id TEXT,"
            "parent_task_id TEXT,"
            "name TEXT NOT NULL,"
            "color_hex TEXT,"
            "icon_system_name TEXT,"
            "type TEXT NOT NULL DEFAULT 'single',"
            "status TEXT NOT NULL DEFAULT 'notDone',"
            "total_amount REAL NOT NULL DEFAULT 0,"
            "current_amount REAL NOT NULL DEFAULT 0,"
            "start_date TEXT,"
            "end_date TEXT,"
            "reminder_date TEXT,"
            "repeat_rule TEXT NOT NULL DEFAULT 'never',"
            "custom_weekdays_raw TEXT,"
            "created_at TEXT NOT NULL,"
            "sort_order INTEGER NOT NULL DEFAULT 0,"
            "FOREIGN KEY (goal_id) REFERENCES Goal(id) ON DELETE CASCADE,"
            "FOREIGN KEY (parent_task_id) REFERENCES TaskItem(id) ON DELETE CASCADE"
            ")"),
        QStringLiteral(
            "CREATE TABLE IF NOT EXISTS AIChatSession ("
            "id TEXT PRIMARY KEY,"
            "goal_id TEXT,"
            "title TEXT NOT NULL DEFAULT '',"
            "created_at TEXT NOT NULL,"
            "updated_at TEXT NOT NULL,"
            "messages_json TEXT NOT NULL DEFAULT '[]',"
            "message_count INTEGER NOT NULL DEFAULT 0,"
            "attachment_name TEXT,"
            "attachment_text TEXT,"
            "FOREIGN KEY (goal_id) REFERENCES Goal(id) ON DELETE CASCADE"
            ")"),
        QStringLiteral(
            "CREATE TABLE IF NOT EXISTS Settings ("
            "key TEXT PRIMARY KEY,"
            "value TEXT"
            ")"),
    };

    for (const QString& stmt : statements) {
        QSqlQuery query(db_);
        if (!query.exec(stmt)) {
            return false;
        }
    }
    return true;
}

} // namespace tick