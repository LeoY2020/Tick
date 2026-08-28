#include "services/jsonbackup.h"

#include <QDateTime>
#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QSqlError>
#include <QSqlQuery>

#include <algorithm>

#include "data/database.h"
#include "data/goalrepository.h"
#include "data/taskrepository.h"
#include "model/enums.h"
#include "model/goal.h"
#include "model/taskitem.h"

namespace tick {

namespace {

QJsonValue optToString(const std::optional<std::string>& v) {
    return v.has_value() ? QJsonValue(QString::fromStdString(*v)) : QJsonValue(QJsonValue::Null);
}

QJsonValue optToDateTime(const std::optional<QDateTime>& v) {
    return v.has_value() ? QJsonValue(v->toString(Qt::ISODateWithMs)) : QJsonValue(QJsonValue::Null);
}

std::optional<QDateTime> dateTimeFromJson(const QJsonValue& v) {
    return dateTimeFromString(v.toString());
}

} // namespace

QJsonObject JsonBackup::taskToJson(const std::shared_ptr<TaskItem>& task) {
    QJsonObject o;
    o.insert(QStringLiteral("id"), QString::fromStdString(task->id));
    o.insert(QStringLiteral("name"), task->name);
    o.insert(QStringLiteral("colorHex"), optToString(task->colorHex));
    o.insert(QStringLiteral("iconSystemName"), optToString(task->iconSystemName));
    o.insert(QStringLiteral("typeRaw"), taskTypeToString(task->type));
    o.insert(QStringLiteral("statusRaw"), taskStatusToString(task->status));
    o.insert(QStringLiteral("totalAmount"), task->totalAmount);
    o.insert(QStringLiteral("currentAmount"), task->currentAmount);
    o.insert(QStringLiteral("startDate"), optToDateTime(task->startDate));
    o.insert(QStringLiteral("endDate"), optToDateTime(task->endDate));
    o.insert(QStringLiteral("reminderDate"), optToDateTime(task->reminderDate));
    o.insert(QStringLiteral("repeatRuleRaw"), task->repeatRule == RepeatRule::Never
                                                 ? QJsonValue(QJsonValue::Null)
                                                 : QJsonValue(repeatRuleToString(task->repeatRule)));
    o.insert(QStringLiteral("customWeekdaysRaw"), optToString(task->customWeekdaysRaw));
    o.insert(QStringLiteral("createdAt"), task->createdAt.toString(Qt::ISODateWithMs));
    o.insert(QStringLiteral("sortOrder"), task->sortOrder);
    QJsonArray subs;
    for (const auto& c : task->subtasks) {
        subs.append(taskToJson(c));
    }
    o.insert(QStringLiteral("subtasks"), subs);
    return o;
}

QJsonObject JsonBackup::goalToJson(const std::shared_ptr<Goal>& goal) {
    QJsonObject o;
    o.insert(QStringLiteral("id"), QString::fromStdString(goal->id));
    o.insert(QStringLiteral("name"), goal->name);
    o.insert(QStringLiteral("colorHex"), QString::fromStdString(goal->colorHex));
    o.insert(QStringLiteral("iconSystemName"), optToString(goal->iconSystemName));
    o.insert(QStringLiteral("startDate"), optToDateTime(goal->startDate));
    o.insert(QStringLiteral("endDate"), optToDateTime(goal->endDate));
    o.insert(QStringLiteral("startDatePreciseToHour"), goal->startDatePreciseToHour);
    o.insert(QStringLiteral("endDatePreciseToHour"), goal->endDatePreciseToHour);
    o.insert(QStringLiteral("createdAt"), goal->createdAt.toString(Qt::ISODateWithMs));
    o.insert(QStringLiteral("progressCountingModeRaw"), countingModeToString(goal->progressCountingMode));
    QJsonArray tasks;
    for (const auto& t : goal->tasks) {
        tasks.append(taskToJson(t));
    }
    o.insert(QStringLiteral("tasks"), tasks);
    return o;
}

QString JsonBackup::exportGoals() {
    GoalRepository goalRepo;
    TaskRepository taskRepo;
    const auto goals = goalRepo.all();
    QJsonArray arr;
    for (auto& g : goals) {
        g->tasks = taskRepo.loadForGoal(g->id);
        arr.append(goalToJson(g));
    }
    QJsonObject root;
    root.insert(QStringLiteral("version"), 1);
    root.insert(QStringLiteral("goals"), arr);
    return QString::fromUtf8(QJsonDocument(root).toJson(QJsonDocument::Indented));
}

std::shared_ptr<TaskItem> JsonBackup::taskFromJson(const QJsonValue& v) {
    auto task = std::make_shared<TaskItem>();
    if (v.isObject()) {
        const QJsonObject o = v.toObject();
        QString id = o.value(QStringLiteral("id")).toString();
        if (!id.isEmpty()) task->id = id.toStdString();
        task->name = o.value(QStringLiteral("name")).toString();
        const QString color = o.value(QStringLiteral("colorHex")).toString();
        task->colorHex = color.isEmpty() ? std::nullopt : std::optional<std::string>(color.toStdString());
        const QString icon = o.value(QStringLiteral("iconSystemName")).toString();
        task->iconSystemName = icon.isEmpty() ? std::nullopt : std::optional<std::string>(icon.toStdString());
        task->type = taskTypeFromString(o.value(QStringLiteral("typeRaw")).toString());
        task->status = taskStatusFromString(o.value(QStringLiteral("statusRaw")).toString());
        task->totalAmount = std::max(0.0, o.value(QStringLiteral("totalAmount")).toDouble());
        task->currentAmount = std::min(std::max(o.value(QStringLiteral("currentAmount")).toDouble(), 0.0),
                                       task->totalAmount);
        task->startDate = dateTimeFromJson(o.value(QStringLiteral("startDate")));
        task->endDate = dateTimeFromJson(o.value(QStringLiteral("endDate")));
        task->reminderDate = dateTimeFromJson(o.value(QStringLiteral("reminderDate")));
        task->repeatRule = repeatRuleFromString(o.value(QStringLiteral("repeatRuleRaw")).toString());
        const QString cw = o.value(QStringLiteral("customWeekdaysRaw")).toString();
        task->customWeekdaysRaw = cw.isEmpty() ? std::nullopt : std::optional<std::string>(cw.toStdString());
        const QDateTime created = dateTimeFromString(o.value(QStringLiteral("createdAt")).toString());
        if (created.isValid()) task->createdAt = created;
        task->sortOrder = o.value(QStringLiteral("sortOrder")).toInt();
        for (const auto& c : o.value(QStringLiteral("subtasks")).toArray()) {
            auto child = taskFromJson(c);
            child->parent = task;
            task->subtasks.push_back(child);
        }
    }
    return task;
}

std::shared_ptr<Goal> JsonBackup::goalFromJson(const QJsonObject& o) {
    auto goal = std::make_shared<Goal>();
    QString id = o.value(QStringLiteral("id")).toString();
    if (!id.isEmpty()) goal->id = id.toStdString();
    goal->name = o.value(QStringLiteral("name")).toString();
    const QString color = o.value(QStringLiteral("colorHex")).toString();
    if (!color.isEmpty()) goal->colorHex = color.toStdString();
    const QString icon = o.value(QStringLiteral("iconSystemName")).toString();
    goal->iconSystemName = icon.isEmpty() ? std::nullopt : std::optional<std::string>(icon.toStdString());
    goal->startDate = dateTimeFromJson(o.value(QStringLiteral("startDate")));
    goal->endDate = dateTimeFromJson(o.value(QStringLiteral("endDate")));
    goal->startDatePreciseToHour = o.value(QStringLiteral("startDatePreciseToHour")).toBool(false);
    goal->endDatePreciseToHour = o.value(QStringLiteral("endDatePreciseToHour")).toBool(false);
    const QDateTime created = dateTimeFromString(o.value(QStringLiteral("createdAt")).toString());
    if (created.isValid()) goal->createdAt = created;
    goal->progressCountingMode = countingModeFromString(
        o.value(QStringLiteral("progressCountingModeRaw")).toString());
    for (const auto& t : o.value(QStringLiteral("tasks")).toArray()) {
        goal->tasks.push_back(taskFromJson(t));
    }
    return goal;
}

bool JsonBackup::importGoals(const QString& json, QString& error) {
    const QJsonDocument doc = QJsonDocument::fromJson(json.toUtf8());
    if (!doc.isObject()) {
        error = QStringLiteral("备份文件格式错误（不是有效的 JSON 对象）");
        return false;
    }
    const QJsonObject root = doc.object();
    const QJsonArray goals = root.value(QStringLiteral("goals")).toArray();

    QSqlQuery clearQuery(Database::instance().connection());
    // 外键级联删除全部任务，仅供导入前清空
    if (!clearQuery.exec(QStringLiteral("DELETE FROM TaskItem"))) {
        error = QStringLiteral("清理旧数据失败：%1").arg(clearQuery.lastError().text());
        return false;
    }
    if (!clearQuery.exec(QStringLiteral("DELETE FROM Goal"))) {
        error = QStringLiteral("清理旧数据失败：%1").arg(clearQuery.lastError().text());
        return false;
    }

    GoalRepository goalRepo;
    TaskRepository taskRepo;
    for (const QJsonValue& gv : goals) {
        const auto goal = goalFromJson(gv.toObject());
        if (goal->name.isEmpty()) continue;
        if (!goalRepo.insert(*goal)) {
            error = QStringLiteral("恢复目标失败：%1").arg(goal->name);
            return false;
        }
        for (const auto& t : goal->tasks) {
            // save 会递归保存整棵子树并正确写入 goal_id / parent_task_id
            taskRepo.save(t, goal->id);
        }
    }
    return true;
}

} // namespace tick