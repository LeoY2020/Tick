#include "data/taskrepository.h"

#include <QDateTime>
#include <QSqlQuery>
#include <QVariant>

#include "data/database.h"

namespace tick {

namespace {

inline QString q(const std::string& s) {
    return QString::fromStdString(s);
}

inline std::optional<std::string> optString(const QString& s) {
    if (s.isEmpty()) return std::nullopt;
    return std::optional<std::string>(s.toStdString());
}

// 列顺序：id, name, color_hex, icon_system_name, type, status, total_amount, current_amount,
// start_date, end_date, reminder_date, repeat_rule, custom_weekdays_raw, created_at, sort_order
std::shared_ptr<TaskItem> parseTaskRow(QSqlQuery& query) {
    auto t = std::make_shared<TaskItem>();
    t->id = query.value(0).toString().toStdString();
    t->name = query.value(1).toString();
    t->colorHex = optString(query.value(2).toString());
    t->iconSystemName = optString(query.value(3).toString());
    t->type = taskTypeFromString(query.value(4).toString());
    t->status = taskStatusFromString(query.value(5).toString());
    t->totalAmount = query.value(6).toDouble();
    t->currentAmount = query.value(7).toDouble();
    t->startDate = dateTimeFromString(query.value(8).toString());
    t->endDate = dateTimeFromString(query.value(9).toString());
    t->reminderDate = dateTimeFromString(query.value(10).toString());
    t->repeatRule = repeatRuleFromString(query.value(11).toString());
    t->customWeekdaysRaw = optString(query.value(12).toString());
    t->createdAt = dateTimeFromString(query.value(13).toString()).value_or(QDateTime::currentDateTime());
    t->sortOrder = query.value(14).toInt();
    return t;
}

} // namespace

std::vector<std::shared_ptr<TaskItem>> TaskRepository::loadForGoal(const std::string& goalId) {
    return loadByParent(q(goalId), true, q(goalId), {});
}

std::vector<std::shared_ptr<TaskItem>> TaskRepository::loadChildren(const QString& parentId,
                                                                   const std::weak_ptr<TaskItem>& parent) {
    return loadByParent(parentId, false, QString(), parent);
}

std::vector<std::shared_ptr<TaskItem>> TaskRepository::loadByParent(const QString& parentId, bool topLevel,
                                                                    const QString& goalId,
                                                                    const std::weak_ptr<TaskItem>& parent) {
    std::vector<std::shared_ptr<TaskItem>> out;
    QSqlQuery query(Database::instance().connection());
    const QString col = topLevel ? QStringLiteral("goal_id") : QStringLiteral("parent_task_id");
    query.prepare(QStringLiteral(
        "SELECT id, name, color_hex, icon_system_name, type, status, total_amount, current_amount, "
        "start_date, end_date, reminder_date, repeat_rule, custom_weekdays_raw, created_at, sort_order "
        "FROM TaskItem WHERE %1 = ? ORDER BY sort_order ASC, created_at ASC").arg(col));
    query.addBindValue(parentId);
    if (!query.exec()) {
        return out;
    }
    while (query.next()) {
        auto t = parseTaskRow(query);
        if (topLevel) {
            t->goalId = goalId.toStdString();
            t->parentTaskId.reset();
            t->parent.reset();
        } else {
            t->goalId.reset();
            t->parentTaskId = parentId.toStdString();
            t->parent = parent;
        }
        t->subtasks = loadChildren(q(t->id), t);
        out.push_back(t);
    }
    return out;
}

void TaskRepository::save(const std::shared_ptr<TaskItem>& task, const std::string& goalId) {
    saveRecursive(task, q(goalId), QString(), true);
}

void TaskRepository::saveRecursive(const std::shared_ptr<TaskItem>& t, const QString& goalId,
                                   const QString& parentId, bool isTopLevel) {
    t->goalId = isTopLevel ? std::optional<std::string>(goalId.toStdString()) : std::nullopt;
    t->parentTaskId = isTopLevel ? std::nullopt : std::optional<std::string>(parentId.toStdString());

    QSqlQuery query(Database::instance().connection());
    query.prepare(QStringLiteral(
        "INSERT INTO TaskItem (id, goal_id, parent_task_id, name, color_hex, icon_system_name, type, status, "
        "total_amount, current_amount, start_date, end_date, reminder_date, repeat_rule, custom_weekdays_raw, "
        "created_at, sort_order) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?) "
        "ON CONFLICT(id) DO UPDATE SET "
        "goal_id = excluded.goal_id, parent_task_id = excluded.parent_task_id, name = excluded.name, "
        "color_hex = excluded.color_hex, icon_system_name = excluded.icon_system_name, "
        "type = excluded.type, status = excluded.status, total_amount = excluded.total_amount, "
        "current_amount = excluded.current_amount, start_date = excluded.start_date, "
        "end_date = excluded.end_date, reminder_date = excluded.reminder_date, "
        "repeat_rule = excluded.repeat_rule, custom_weekdays_raw = excluded.custom_weekdays_raw, "
        "created_at = excluded.created_at, sort_order = excluded.sort_order"));
    query.addBindValue(q(t->id));
    query.addBindValue(t->goalId.has_value() ? q(*t->goalId) : QVariant());
    query.addBindValue(t->parentTaskId.has_value() ? q(*t->parentTaskId) : QVariant());
    query.addBindValue(t->name);
    query.addBindValue(t->colorHex.has_value() ? q(*t->colorHex) : QVariant());
    query.addBindValue(t->iconSystemName.has_value() ? q(*t->iconSystemName) : QVariant());
    query.addBindValue(taskTypeToString(t->type));
    query.addBindValue(taskStatusToString(t->status));
    query.addBindValue(t->totalAmount);
    query.addBindValue(t->currentAmount);
    query.addBindValue(dateTimeToString(t->startDate));
    query.addBindValue(dateTimeToString(t->endDate));
    query.addBindValue(dateTimeToString(t->reminderDate));
    query.addBindValue(repeatRuleToString(t->repeatRule));
    query.addBindValue(t->customWeekdaysRaw.has_value() ? q(*t->customWeekdaysRaw) : QVariant());
    query.addBindValue(t->createdAt.toString(Qt::ISODateWithMs));
    query.addBindValue(t->sortOrder);
    query.exec();

    for (const auto& c : t->subtasks) {
        saveRecursive(c, goalId, q(t->id), false);
    }
}

void TaskRepository::remove(const std::shared_ptr<TaskItem>& task) {
    QSqlQuery query(Database::instance().connection());
    query.prepare(QStringLiteral("DELETE FROM TaskItem WHERE id = ?"));
    query.addBindValue(q(task->id));
    query.exec();
}

} // namespace tick