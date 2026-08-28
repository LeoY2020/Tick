#pragma once

#include <QJsonObject>
#include <QJsonValue>
#include <QString>

#include <memory>
#include <vector>

namespace tick {

class Goal;
class TaskItem;

// 应用数据 JSON 备份：导出全部目标与任务（含嵌套树）为一个 JSON 文件，并可导入恢复。
// 与 iOS 版 DataBackupManager 的 AppDataSnapshot / GoalDTO / TaskDTO 结构保持一致。
class JsonBackup {
public:
    /// 导出全部目标与任务为 JSON 字符串（空 → 失败）
    static QString exportGoals();

    /// 清空现有数据后从 JSON 恢复（还原失败时返回 false 并填充 error）
    static bool importGoals(const QString& json, QString& error);

private:
    static QJsonObject goalToJson(const std::shared_ptr<Goal>& goal);
    static QJsonObject taskToJson(const std::shared_ptr<TaskItem>& task);
    static std::shared_ptr<Goal> goalFromJson(const QJsonObject& o);
    static std::shared_ptr<TaskItem> taskFromJson(const QJsonValue& v);
};

} // namespace tick