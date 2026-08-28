#pragma once

#include <QDateTime>

#include <optional>
#include <string>
#include <utility>

#include "model/goal.h"
#include "model/taskitem.h"

namespace tick {

// 目标总进度结果
struct GoalProgress {
    /// 计入总量的任务数（删除态不计）
    int totalItems = 0;
    /// 加权完成度（单项完成=1 半完成=0.5；进度=比率）
    double completedWeight = 0.0;

    /// completedWeight / totalItems，无任务时为 0
    double fraction() const {
        return totalItems == 0 ? 0.0 : completedWeight / static_cast<double>(totalItems);
    }
};

// 递归进度计算引擎：自底向上汇总（纯计算，不修改模型数据）
class ProgressEngine {
public:
    // ---- 有效状态与有效进度 ----

    /// 有效状态：有子任务（被接管）时由直接子任务计算，否则用手动状态
    static TaskStatus effectiveStatus(const TaskItem& task);

    /// 有效进度：有子任务（被接管）时由直接子任务汇总，否则用手动值（clamp 到 0...total）
    static std::pair<double, double> effectiveProgress(const TaskItem& task);

    // ---- 目标总进度 ----
    static GoalProgress goalProgress(const Goal& goal);

    // ---- 继承链解析（向上沿父链取最近已设值，最终回退 Goal）----
    static std::string effectiveColor(const TaskItem& task, const Goal* goal = nullptr);
    static std::optional<std::string> effectiveIcon(const TaskItem& task, const Goal* goal = nullptr);
    static std::optional<QDateTime> effectiveStartDate(const TaskItem& task, const Goal* goal = nullptr);
    static std::optional<QDateTime> effectiveEndDate(const TaskItem& task, const Goal* goal = nullptr);

    // ---- 子任务贡献（供测试与汇总复用）----
    static std::pair<double, double> childContribution(const TaskItem& task);

    // ---- 单项状态权重 ----
    static double statusWeight(TaskStatus status);

    // ---- 删除态判定（任何层级均不计入总量和进度）----
    static bool isDeleted(const TaskItem& task);

private:
    static std::pair<double, double> manualProgress(const TaskItem& task);
    static TaskStatus subtaskStatus(const TaskItem& task);
    static double taskWeight(const TaskItem& task);
    static double effectiveRatio(const TaskItem& task);

    static void accumulate(const TaskItem& task, ProgressCountingMode mode,
                           int& totalItems, double& completedWeight);
};

} // namespace tick