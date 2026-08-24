import Foundation
import SwiftData

/// 目标：顶层组织单元（CloudKit 兼容——所有属性有默认值或可选，不使用唯一约束）
@Model
final class Goal {
    var id: UUID = UUID()
    var name: String = ""
    /// 颜色 HEX 字符串（如 "#000000"）
    var colorHex: String = "#000000"
    /// SF Symbols 图标名（nil = 未设置）
    var iconSystemName: String? = nil
    /// 开始日期（nil = 未设置）
    var startDate: Date? = nil
    /// 截止日期（nil = 未设置）
    var endDate: Date? = nil
    var createdAt: Date = Date()

    /// 目标下的一级任务（删除目标时级联删除全部任务）
    @Relationship(deleteRule: .cascade, inverse: \TaskItem.goal)
    var tasks: [TaskItem] = []

    init(name: String,
         colorHex: String = "#000000",
         iconSystemName: String? = nil,
         startDate: Date? = nil,
         endDate: Date? = nil) {
        self.name = name
        self.colorHex = colorHex
        self.iconSystemName = iconSystemName
        self.startDate = startDate
        self.endDate = endDate
    }
}
