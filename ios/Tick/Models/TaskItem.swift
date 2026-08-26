import Foundation
import SwiftData

/// 任务：支持无限层级嵌套（自引用 parentTask/subtasks 关系）。
/// 注意：类名避开 Task，防止与 Swift 并发 Task 冲突。
/// CloudKit 兼容——所有属性有默认值或可选，不使用唯一约束。
@Model
final class TaskItem {
    var id: UUID = UUID()
    var name: String = ""
    /// 颜色 HEX（nil = 继承父级）
    var colorHex: String? = nil
    /// SF Symbols 图标名（nil = 继承父级）
    var iconSystemName: String? = nil
    /// 任务类型（TaskType 原始值）
    var typeRaw: String = TaskType.single.rawValue
    /// 任务状态（TaskStatus 原始值）
    var statusRaw: String = TaskStatus.notDone.rawValue
    /// 进度类型总量
    var totalAmount: Double = 0
    /// 进度类型当前值（约束 0 ≤ 当前 ≤ 总量）
    var currentAmount: Double = 0
    /// 开始日期（nil = 继承父级）
    var startDate: Date? = nil
    /// 截止日期（nil = 继承父级）
    var endDate: Date? = nil
    /// 提醒时间（nil = 不提醒）
    var reminderDate: Date? = nil
    /// 重复规则（nil / never = 不重复）
    var repeatRuleRaw: String? = nil
    /// 自定义重复的星期，逗号分隔（如 "1,3,5"，1=周日…7=周六）
    var customWeekdaysRaw: String? = nil
    var createdAt: Date = Date()
    /// 排序值
    var sortOrder: Int = 0

    /// 一级任务归属的目标（与 parentTask 互斥）
    var goal: Goal? = nil
    /// 父任务（nil = 一级任务，与 goal 互斥）
    var parentTask: TaskItem? = nil
    /// 子任务（删除任务时级联删除全部后代）
    @Relationship(deleteRule: .cascade, inverse: \TaskItem.parentTask)
    var subtasks: [TaskItem] = []

    // MARK: - 计算属性

    /// 任务类型（读写映射枚举，未知原始值回退 single）
    var type: TaskType {
        get { TaskType(rawValue: typeRaw) ?? .single }
        set { typeRaw = newValue.rawValue }
    }

    /// 任务状态（读写映射枚举，未知原始值回退 notDone）
    var status: TaskStatus {
        get { TaskStatus(rawValue: statusRaw) ?? .notDone }
        set { statusRaw = newValue.rawValue }
    }

    /// 重复规则（可选读写映射）
    var repeatRule: RepeatRule? {
        get { repeatRuleRaw.flatMap { RepeatRule(rawValue: $0) } }
        set { repeatRuleRaw = newValue?.rawValue }
    }

    /// 是否拥有子任务（接管机制判定依据）
    var hasSubtasks: Bool {
        !subtasks.isEmpty
    }

    // MARK: - 便捷方法

    /// 设置进度并 clamp 到 0...totalAmount
    func setProgress(_ value: Double) {
        currentAmount = min(max(value, 0), totalAmount)
    }

    /// 解析自定义重复的星期（1=周日…7=周六），过滤非法值
    func effectiveWeekdays() -> [Int] {
        guard let raw = customWeekdaysRaw else { return [] }
        return raw.split(separator: ",")
            .compactMap { Int($0.trimmingCharacters(in: .whitespaces)) }
            .filter { (1...7).contains($0) }
    }

    // MARK: - 关系维护（goal 与 parentTask 互斥）

    /// 作为一级任务挂到目标
    func attach(to goal: Goal) {
        parentTask = nil
        self.goal = goal
    }

    /// 作为子任务挂到父任务（通过父链继承目标属性）
    func attach(to parent: TaskItem) {
        goal = nil
        parentTask = parent
    }

    // MARK: - 初始化

    init(name: String,
         type: TaskType = .single,
         colorHex: String? = nil,
         iconSystemName: String? = nil,
         status: TaskStatus = .notDone,
         totalAmount: Double = 0,
         currentAmount: Double = 0,
         startDate: Date? = nil,
         endDate: Date? = nil,
         reminderDate: Date? = nil,
         repeatRule: RepeatRule? = nil,
         customWeekdaysRaw: String? = nil,
         sortOrder: Int = 0) {
        self.name = name
        self.colorHex = colorHex
        self.iconSystemName = iconSystemName
        self.typeRaw = type.rawValue
        self.statusRaw = status.rawValue
        // 总量与当前值均在 init 中 clamp
        let total = max(0, totalAmount)
        self.totalAmount = total
        self.currentAmount = min(max(currentAmount, 0), total)
        self.startDate = startDate
        self.endDate = endDate
        self.reminderDate = reminderDate
        self.repeatRuleRaw = repeatRule?.rawValue
        self.customWeekdaysRaw = customWeekdaysRaw
        self.sortOrder = sortOrder
    }
}
