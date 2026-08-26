import Foundation
import SwiftData

/// 目标：顶层组织单元（CloudKit 兼容——所有属性有默认值或可选，不使用唯一约束）
@Model
final class Goal {
    var id: UUID = UUID()
    var name: String = ""
    /// 颜色 HEX 字符串（如 "#000000"；"auto" = 自动：深色模式白 / 浅色模式黑）
    var colorHex: String = "auto"
    /// SF Symbols 图标名（nil = 未设置）
    var iconSystemName: String? = nil
    /// 开始日期（nil = 未设置）
    var startDate: Date? = nil
    /// 截止日期（nil = 未设置）
    var endDate: Date? = nil
    /// 开始时间是否精确到小时（编辑时 DatePicker 显示时分；未开启仅精确到日期）
    var startDatePreciseToHour: Bool = false
    /// 截止时间是否精确到小时（影响主界面倒计时是否显示"时"）
    var endDatePreciseToHour: Bool = false
    var createdAt: Date = Date()
    /// 进度统计模式原始值（String? 存储，nil=未设置=>回退 allTasks。
    /// 与 TaskItem.typeRaw 同款思路，但用 Optional：以字符串且可选方式入库，
    /// 避免 Codable 枚举列在 SwiftData/CloudKit 已有数据的迁移/解码崩溃）
    var progressCountingModeRaw: String? = nil
    /// 进度统计模式（读写映射枚举，unknow/未设置 回退 allTasks）
    var progressCountingMode: ProgressCountingMode {
        get { ProgressCountingMode(rawValue: progressCountingModeRaw ?? ProgressCountingMode.allTasks.rawValue) ?? .allTasks }
        set { progressCountingModeRaw = newValue.rawValue }
    }

    /// 目标下的一级任务（删除目标时级联删除全部任务）
    @Relationship(deleteRule: .cascade, inverse: \TaskItem.goal)
    var tasks: [TaskItem] = []

    /// 无参初始化（新建目标占位、视图兜底场景；其余属性取默认值）
    init() {
        self.name = ""
    }

    init(name: String,
         colorHex: String = "auto",
         iconSystemName: String? = nil,
         startDate: Date? = nil,
         endDate: Date? = nil,
         startDatePreciseToHour: Bool = false,
         endDatePreciseToHour: Bool = false,
         progressCountingMode: ProgressCountingMode = .allTasks) {
        self.name = name
        self.colorHex = colorHex
        self.iconSystemName = iconSystemName
        self.startDate = startDate
        self.endDate = endDate
        self.startDatePreciseToHour = startDatePreciseToHour
        self.endDatePreciseToHour = endDatePreciseToHour
        // 直接写原始值字符串，避免 init 阶段经由计算属性 setter
        self.progressCountingModeRaw = progressCountingMode.rawValue
    }
}
