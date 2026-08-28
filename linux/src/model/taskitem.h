#pragma once

#include <QDateTime>
#include <QStringList>

#include <memory>
#include <optional>
#include <string>
#include <vector>

#include "enums.h"

namespace tick {

// 任务：支持无限层级嵌套。
// 用 shared_ptr 表达子树，parent 用 weak_ptr 避免循环引用；
// goalId 与 parentTaskId 互斥（一级任务挂 goal，子任务挂 parent）。
struct TaskItem : std::enable_shared_from_this<TaskItem> {
    std::string id = makeId();
    QString name;
    /// 颜色 HEX（nullopt = 继承父级）
    std::optional<std::string> colorHex;
    /// 图标名（nullopt = 继承父级）
    std::optional<std::string> iconSystemName;
    TaskType type = TaskType::Single;
    TaskStatus status = TaskStatus::NotDone;
    /// 进度类型总量
    double totalAmount = 0.0;
    /// 进度类型当前值（约束 0 ≤ 当前 ≤ 总量）
    double currentAmount = 0.0;
    /// 开始日期（nullopt = 继承父级）
    std::optional<QDateTime> startDate;
    /// 截止日期（nullopt = 继承父级）
    std::optional<QDateTime> endDate;
    /// 提醒时间（nullopt = 不提醒）
    std::optional<QDateTime> reminderDate;
    /// 重复规则（Never = 不重复）
    RepeatRule repeatRule = RepeatRule::Never;
    /// 自定义重复的星期，逗号分隔（如 "1,3,5"，1=周日…7=周六）
    std::optional<std::string> customWeekdaysRaw;
    QDateTime createdAt = QDateTime::currentDateTime();
    /// 排序值
    int sortOrder = 0;

    /// 一级任务归属的目标 id（与 parentTaskId 互斥）
    std::optional<std::string> goalId;
    /// 父任务 id（nullopt = 一级任务，与 goalId 互斥）
    std::optional<std::string> parentTaskId;

    /// 子任务
    std::vector<std::shared_ptr<TaskItem>> subtasks;
    /// 父任务（弱指针，避免循环引用）
    std::weak_ptr<TaskItem> parent;

    /// 是否拥有子任务（接管机制判定依据）
    bool hasSubtasks() const { return !subtasks.empty(); }

    /// 设置进度并 clamp 到 0...totalAmount
    void setProgress(double value) {
        currentAmount = value;
        if (currentAmount < 0) currentAmount = 0;
        if (currentAmount > totalAmount) currentAmount = totalAmount;
    }

    /// 解析自定义重复的星期（1=周日…7=周六），过滤非法值
    std::vector<int> effectiveWeekdays() const {
        std::vector<int> out;
        if (!customWeekdaysRaw.has_value()) return out;
        // 简单拆分：按逗号切分，trim 后尝试转整数，保留 1..7
        QString raw = QString::fromStdString(*customWeekdaysRaw);
        const QStringList parts = raw.split(QLatin1Char(','), Qt::SkipEmptyParts);
        for (const QString& p : parts) {
            bool ok = false;
            const int v = p.trimmed().toInt(&ok);
            if (ok && v >= 1 && v <= 7) out.push_back(v);
        }
        return out;
    }
};

} // namespace tick