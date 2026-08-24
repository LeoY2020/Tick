import Foundation

/// 任务类型：单项 / 进度
enum TaskType: String, Codable, CaseIterable {
    /// 单项任务
    case single
    /// 进度任务
    case progress

    /// 中文显示名
    var displayName: String {
        switch self {
        case .single: return "单项"
        case .progress: return "进度"
        }
    }
}

/// 任务状态：未完成 → 半完成 → 完成 / 删除
enum TaskStatus: String, Codable, CaseIterable {
    /// 未完成
    case notDone
    /// 半完成
    case halfDone
    /// 完成
    case done
    /// 删除（不计入进度）
    case deleted

    /// 中文显示名
    var displayName: String {
        switch self {
        case .notDone: return "未完成"
        case .halfDone: return "半完成"
        case .done: return "完成"
        case .deleted: return "删除"
        }
    }
}

/// 目标进度统计模式
enum ProgressCountingMode: String, Codable, CaseIterable {
    /// 统计父任务：所有层级任务均计入总量与进度（父任务按其有效状态/进度折算）
    case allTasks
    /// 统计叶子任务：只统计任务树末端（无有效子任务）的节点
    case leafTasks

    /// 中文显示名
    var displayName: String {
        switch self {
        case .allTasks: return "全部任务"
        case .leafTasks: return "仅叶子任务"
        }
    }
}

/// 提醒重复规则
enum RepeatRule: String, Codable, CaseIterable {
    /// 不重复
    case never
    /// 每天
    case daily
    /// 每周
    case weekly
    /// 每月
    case monthly
    /// 自定义（周几多选）
    case custom

    /// 中文显示名
    var displayName: String {
        switch self {
        case .never: return "不重复"
        case .daily: return "每天"
        case .weekly: return "每周"
        case .monthly: return "每月"
        case .custom: return "自定义"
        }
    }
}
