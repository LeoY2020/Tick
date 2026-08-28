#include "domain/progressengine.h"

#include <algorithm>
#include <functional>

namespace tick {

// 删除态判定：单项且状态为删除
bool ProgressEngine::isDeleted(const TaskItem& task) {
    return task.type == TaskType::Single && task.status == TaskStatus::Deleted;
}

// 单项状态权重：完成=1 半完成=0.5 未完成/删除=0
double ProgressEngine::statusWeight(TaskStatus status) {
    switch (status) {
        case TaskStatus::Done: return 1.0;
        case TaskStatus::HalfDone: return 0.5;
        case TaskStatus::NotDone:
        case TaskStatus::Deleted: return 0.0;
    }
    return 0.0;
}

// 手动进度：current clamp 到 0...total，total 取非负
std::pair<double, double> ProgressEngine::manualProgress(const TaskItem& task) {
    const double total = std::max(0.0, task.totalAmount);
    const double current = std::min(std::max(task.currentAmount, 0.0), total);
    return {current, total};
}

// 子任务折算状态：单项用有效状态；进度按有效比率折算（1→完成，0<比率<1→半完成，0→未完成）
TaskStatus ProgressEngine::subtaskStatus(const TaskItem& task) {
    if (task.type != TaskType::Progress) {
        return effectiveStatus(task);
    }
    const double ratio = effectiveRatio(task);
    if (ratio >= 1.0) return TaskStatus::Done;
    if (ratio > 0.0) return TaskStatus::HalfDone;
    return TaskStatus::NotDone;
}

// 有效状态：有子任务（被接管）时由直接子任务计算，否则用手动状态
TaskStatus ProgressEngine::effectiveStatus(const TaskItem& task) {
    // 未接管：手动状态
    if (!task.hasSubtasks()) return task.status;

    // 被接管：由直接子任务折算（删除态子任务跳过）
    bool hasDone = false;
    bool hasHalf = false;
    bool hasNotDone = false;
    for (const auto& sub : task.subtasks) {
        if (isDeleted(*sub)) continue;
        switch (subtaskStatus(*sub)) {
            case TaskStatus::Done: hasDone = true; break;
            case TaskStatus::HalfDone: hasHalf = true; break;
            case TaskStatus::NotDone: hasNotDone = true; break;
            case TaskStatus::Deleted: break; // 已被过滤
        }
    }
    // 三者全空（有效子任务全部删除）→ 接管解除，回落手动状态
    if (!hasDone && !hasHalf && !hasNotDone) return task.status;
    // 存在半完成或混合 → 半完成；否则全完成 → 完成，其余 → 未完成
    if (hasHalf || (hasDone && hasNotDone)) return TaskStatus::HalfDone;
    return hasDone ? TaskStatus::Done : TaskStatus::NotDone;
}

// 有效进度：有子任务（被接管）时由直接子任务汇总，否则用手动值
std::pair<double, double> ProgressEngine::effectiveProgress(const TaskItem& task) {
    // 未接管：手动值
    if (!task.hasSubtasks()) return manualProgress(task);

    // 被接管：当前=子任务当前之和，总量=子任务总量之和（忽略手动总量）
    double current = 0.0;
    double total = 0.0;
    bool hasCounting = false;
    for (const auto& sub : task.subtasks) {
        if (isDeleted(*sub)) continue;
        hasCounting = true;
        const auto contribution = childContribution(*sub);
        current += contribution.first;
        total += contribution.second;
    }
    // 有效子任务全部删除 → 接管解除，回落手动值
    if (hasCounting) return {current, total};
    return manualProgress(task);
}

// 有效比率：current / total（total ≤ 0 时为 0，上限 1）
double ProgressEngine::effectiveRatio(const TaskItem& task) {
    const auto progress = effectiveProgress(task);
    if (progress.second <= 0.0) return 0.0;
    return std::min(progress.first / progress.second, 1.0);
}

// 子任务贡献：单项 → (状态权重, 1)；进度 → 有效 (current, total)；删除态 → (0, 0)
std::pair<double, double> ProgressEngine::childContribution(const TaskItem& task) {
    if (isDeleted(task)) return {0.0, 0.0};
    if (task.type == TaskType::Single) {
        return {statusWeight(effectiveStatus(task)), 1.0};
    }
    return effectiveProgress(task);
}

// 单个任务节点的权重：单项 → 有效状态权重；进度 → 有效比率
double ProgressEngine::taskWeight(const TaskItem& task) {
    if (task.type == TaskType::Single) {
        return statusWeight(effectiveStatus(task));
    }
    return effectiveRatio(task);
}

// 递归累计任务树
void ProgressEngine::accumulate(const TaskItem& task, ProgressCountingMode mode,
                                int& totalItems, double& completedWeight) {
    // 删除态：整棵子树不计入总量与进度
    if (isDeleted(task)) return;

    switch (mode) {
        case ProgressCountingMode::AllTasks: {
            ++totalItems;
            completedWeight += taskWeight(task);
            for (const auto& sub : task.subtasks) {
                accumulate(*sub, mode, totalItems, completedWeight);
            }
            break;
        }
        case ProgressCountingMode::LeafTasks: {
            // 有效（非删除）子任务为空 → 叶子节点计入；否则只递归子任务
            bool hasActive = false;
            for (const auto& sub : task.subtasks) {
                if (!isDeleted(*sub)) { hasActive = true; break; }
            }
            if (!hasActive) {
                ++totalItems;
                completedWeight += taskWeight(task);
            } else {
                for (const auto& sub : task.subtasks) {
                    accumulate(*sub, mode, totalItems, completedWeight);
                }
            }
            break;
        }
    }
}

// 目标总进度：按统计模式递归统计整棵任务树
GoalProgress ProgressEngine::goalProgress(const Goal& goal) {
    int totalItems = 0;
    double completedWeight = 0.0;
    for (const auto& task : goal.tasks) {
        accumulate(*task, goal.progressCountingMode, totalItems, completedWeight);
    }
    GoalProgress p;
    p.totalItems = totalItems;
    p.completedWeight = completedWeight;
    return p;
}

// ---- 继承链解析 ----

static const TaskItem* parentOrNull(const TaskItem& task) {
    std::shared_ptr<TaskItem> p = task.parent.lock();
    return p.get();
}

std::string ProgressEngine::effectiveColor(const TaskItem& task, const Goal* goal) {
    const TaskItem* cursor = &task;
    while (cursor) {
        if (cursor->colorHex.has_value() && !cursor->colorHex->empty()) return *cursor->colorHex;
        cursor = parentOrNull(*cursor);
    }
    if (goal) return goal->colorHex;
    return "#000000";
}

std::optional<std::string> ProgressEngine::effectiveIcon(const TaskItem& task, const Goal* goal) {
    const TaskItem* cursor = &task;
    while (cursor) {
        if (cursor->iconSystemName.has_value() && !cursor->iconSystemName->empty()) return *cursor->iconSystemName;
        cursor = parentOrNull(*cursor);
    }
    if (goal && goal->iconSystemName.has_value()) return goal->iconSystemName;
    return std::nullopt;
}

std::optional<QDateTime> ProgressEngine::effectiveStartDate(const TaskItem& task, const Goal* goal) {
    const TaskItem* cursor = &task;
    while (cursor) {
        if (cursor->startDate.has_value()) return cursor->startDate;
        cursor = parentOrNull(*cursor);
    }
    if (goal && goal->startDate.has_value()) return goal->startDate;
    return std::nullopt;
}

std::optional<QDateTime> ProgressEngine::effectiveEndDate(const TaskItem& task, const Goal* goal) {
    const TaskItem* cursor = &task;
    while (cursor) {
        if (cursor->endDate.has_value()) return cursor->endDate;
        cursor = parentOrNull(*cursor);
    }
    if (goal && goal->endDate.has_value()) return goal->endDate;
    return std::nullopt;
}

} // namespace tick