#pragma once

#include <QDateTime>

#include <memory>
#include <optional>
#include <string>
#include <vector>

#include "enums.h"

namespace tick {

class TaskItem;

// 目标：顶层组织单元，持有其下的一级任务
struct Goal {
    std::string id = makeId();
    QString name;
    /// 颜色 HEX 字符串（如 "#000000"；"auto" = 跟随系统：深色白 / 浅色黑）
    std::string colorHex = "auto";
    /// 图标名（nullopt = 未设置）
    std::optional<std::string> iconSystemName;
    /// 开始日期（nullopt = 未设置）
    std::optional<QDateTime> startDate;
    /// 截止日期（nullopt = 未设置）
    std::optional<QDateTime> endDate;
    /// 开始时间是否精确到小时
    bool startDatePreciseToHour = false;
    /// 截止时间是否精确到小时
    bool endDatePreciseToHour = false;
    QDateTime createdAt = QDateTime::currentDateTime();
    /// 进度统计模式
    ProgressCountingMode progressCountingMode = ProgressCountingMode::AllTasks;

    /// 一级任务（删除目标时级联删除全部任务）
    std::vector<std::shared_ptr<TaskItem>> tasks;
};

} // namespace tick