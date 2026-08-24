import Foundation

/// 目标总进度结果
struct GoalProgress: Equatable {
    /// 计入总量的任务数（删除态不计）
    var totalItems: Int
    /// 加权完成度（单项完成=1 半完成=0.5；进度=比率）
    var completedWeight: Double
    /// completedWeight / totalItems，无任务时为 0
    var fraction: Double {
        totalItems == 0 ? 0 : completedWeight / Double(totalItems)
    }
}

/// 递归进度计算引擎：自底向上汇总（纯计算，不修改模型数据）
enum ProgressEngine {

    // MARK: - 有效状态与有效进度

    /// 有效状态：有子任务（被接管）时由直接子任务计算，否则用手动状态
    static func effectiveStatus(of task: TaskItem) -> TaskStatus {
        // 未接管：手动状态
        guard task.hasSubtasks else { return task.status }

        // 被接管：由直接子任务折算（删除态子任务跳过）
        var hasDone = false
        var hasHalf = false
        var hasNotDone = false
        for sub in task.subtasks where !isDeleted(sub) {
            switch subtaskStatus(of: sub) {
            case .done: hasDone = true
            case .halfDone: hasHalf = true
            case .notDone: hasNotDone = true
            case .deleted: break // 已被过滤，不会到达
            }
        }
        // 有效子任务全部删除 → 接管解除，回落手动状态
        if !hasDone && !hasHalf && !hasNotDone { return task.status }
        // 全部完成 → 完成；全部未完成 → 未完成；存在半完成或混合 → 半完成
        if hasHalf || (hasDone && hasNotDone) { return .halfDone }
        return hasDone ? .done : .notDone
    }

    /// 有效进度：有子任务（被接管）时由直接子任务汇总，否则用手动值（clamp 到 0...total）
    static func effectiveProgress(of task: TaskItem) -> (current: Double, total: Double) {
        // 未接管：手动值
        guard task.hasSubtasks else { return manualProgress(of: task) }

        // 被接管：当前=子任务当前之和，总量=子任务总量之和（忽略手动总量）
        var current = 0.0
        var total = 0.0
        var hasCounting = false
        for sub in task.subtasks where !isDeleted(sub) {
            hasCounting = true
            let contribution = childContribution(of: sub)
            current += contribution.current
            total += contribution.total
        }
        // 有效子任务全部删除 → 接管解除，回落手动值
        if hasCounting { return (current, total) }
        return manualProgress(of: task)
    }

    // MARK: - 目标总进度

    /// 目标总进度：遍历一级任务，删除态单项不计入总量与进度
    static func goalProgress(of goal: Goal) -> GoalProgress {
        var totalItems = 0
        var completedWeight = 0.0
        for task in goal.tasks {
            // 跳过删除态单项
            if isDeleted(task) { continue }
            totalItems += 1
            if task.type == .single {
                // 单项：状态权重（被接管时为折算状态）
                completedWeight += statusWeight(of: effectiveStatus(of: task))
            } else {
                // 进度：有效比率
                completedWeight += effectiveRatio(of: task)
            }
        }
        return GoalProgress(totalItems: totalItems, completedWeight: completedWeight)
    }

    // MARK: - 继承链解析

    /// 有效颜色：子任务 → 父任务 → … → 父目标，取最近已设置值；最终回退 "#000000"
    static func effectiveColor(of task: TaskItem) -> String {
        var cursor: TaskItem? = task
        while let current = cursor {
            if let hex = current.colorHex, !hex.isEmpty { return hex }
            cursor = current.parentTask
        }
        return rootGoal(of: task)?.colorHex ?? "#000000"
    }

    /// 有效图标：沿父链取最近已设置值，最终回退所属 Goal 的图标
    static func effectiveIcon(of task: TaskItem) -> String? {
        var cursor: TaskItem? = task
        while let current = cursor {
            if let icon = current.iconSystemName, !icon.isEmpty { return icon }
            cursor = current.parentTask
        }
        return rootGoal(of: task)?.iconSystemName
    }

    /// 有效开始日期：沿父链取最近已设置值，最终回退所属 Goal
    static func effectiveStartDate(of task: TaskItem) -> Date? {
        var cursor: TaskItem? = task
        while let current = cursor {
            if let date = current.startDate { return date }
            cursor = current.parentTask
        }
        return rootGoal(of: task)?.startDate
    }

    /// 有效截止日期：沿父链取最近已设置值，最终回退所属 Goal
    static func effectiveEndDate(of task: TaskItem) -> Date? {
        var cursor: TaskItem? = task
        while let current = cursor {
            if let date = current.endDate { return date }
            cursor = current.parentTask
        }
        return rootGoal(of: task)?.endDate
    }

    /// 沿 parentTask 链向上找到所属 Goal
    static func rootGoal(of task: TaskItem) -> Goal? {
        var cursor: TaskItem? = task
        while let current = cursor {
            if let goal = current.goal { return goal }
            cursor = current.parentTask
        }
        return nil
    }

    // MARK: - 子任务贡献

    /// 单个子任务对父级进度汇总的贡献：单项 → (状态权重, 1)；进度 → 有效 (current, total)。
    /// 删除态单项不计入（返回 (0, 0)，由调用方跳过）。
    static func childContribution(of task: TaskItem) -> (current: Double, total: Double) {
        // 删除态单项不计入
        if isDeleted(task) { return (0, 0) }
        if task.type == .single {
            // 单项：总量=1，当前=状态权重（被接管时取折算状态）
            return (statusWeight(of: effectiveStatus(of: task)), 1)
        }
        // 进度：有效 (current, total)
        return effectiveProgress(of: task)
    }

    // MARK: - 私有辅助

    /// 删除态判定：单项且状态为删除（spec：任何层级均不计入总量和进度）
    private static func isDeleted(_ task: TaskItem) -> Bool {
        task.type == .single && task.status == .deleted
    }

    /// 手动进度：current clamp 到 0...total，total 取非负
    private static func manualProgress(of task: TaskItem) -> (current: Double, total: Double) {
        let total = max(0, task.totalAmount)
        let current = min(max(task.currentAmount, 0), total)
        return (current, total)
    }

    /// 单项状态权重：完成=1 半完成=0.5 未完成/删除=0
    private static func statusWeight(of status: TaskStatus) -> Double {
        switch status {
        case .done: return 1
        case .halfDone: return 0.5
        case .notDone, .deleted: return 0
        }
    }

    /// 子任务折算状态：单项用有效状态；进度按有效比率折算（1→完成，0<比率<1→半完成，0→未完成）
    private static func subtaskStatus(of sub: TaskItem) -> TaskStatus {
        guard sub.type == .progress else { return effectiveStatus(of: sub) }
        let ratio = effectiveRatio(of: sub)
        if ratio >= 1 { return .done }
        if ratio > 0 { return .halfDone }
        return .notDone
    }

    /// 有效比率：current / total（total ≤ 0 时为 0，上限 1）
    private static func effectiveRatio(of task: TaskItem) -> Double {
        let progress = effectiveProgress(of: task)
        guard progress.total > 0 else { return 0 }
        return min(progress.current / progress.total, 1)
    }
}
