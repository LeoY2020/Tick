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
    var createdAt: Date = Date()
    /// 进度统计模式：全部任务（父任务折算计入）/ 仅叶子任务（任务树末端节点）
    /// 注意：SwiftData 宏要求默认值使用全限定枚举名（ProgressCountingMode.allTasks）
    var progressCountingMode: ProgressCountingMode = ProgressCountingMode.allTasks

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
         progressCountingMode: ProgressCountingMode = .allTasks) {
        self.name = name
        self.colorHex = colorHex
        self.iconSystemName = iconSystemName
        self.startDate = startDate
        self.endDate = endDate
        self.progressCountingMode = progressCountingMode
    }
}
