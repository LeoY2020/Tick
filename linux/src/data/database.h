#pragma once

#include <QSqlDatabase>
#include <QString>

namespace tick {

// SQLite 数据库连接（单例，四张表：Goal / TaskItem / AIChatSession / Settings）
class Database {
public:
    static Database& instance();

    /// 打开（或创建）数据库并建表；path 为空时使用用户数据目录
    bool initialize(const QString& path = QString());

    QSqlDatabase connection() const;
    bool isOpen() const;
    QString errorString() const;

private:
    Database();
    bool createSchema();

    QSqlDatabase db_;
};

} // namespace tick